dgram = require 'dgram'
socketIo = require 'socket.io'

miaGame = require './miaGame'
remotePlayer = require './remotePlayer'

class Server
	log = ->

	constructor: (@game, port, callback) ->
		handleRawMessage = (message, connection) =>
			log "received '#{message}' from #{connection}"
			messageParts = message.split ';'
			command = messageParts[0]
			args = messageParts[1..]
			@handleMessage command, args, connection

		initUdpSocket = (port) =>
			@udpSocket = dgram.createSocket 'udp4', (message, address) =>
				handleRawMessage message.toString(), new UdpConnection address, @udpSocket
			@udpSocket.bind port

		initWebSocket = (port) =>
			@webSocket = socketIo.listen port, callback
			@webSocket.set 'client store expiration', .2
			@webSocket.set 'log level', 0
			@webSocket.sockets.on 'connection', (socket) ->
				socket.on 'message', (message) ->
					handleRawMessage message, new WebSocketConnection socket.handshake.address, socket

		initUdpSocket port
		initWebSocket port
		@players = {}

	enableLogging: -> log = console.log

	handleMessage: (messageCommand, messageArgs, connection) ->
		log "handleMessage '#{messageCommand}' '#{messageArgs}' from #{connection.id}"
		if messageCommand == 'REGISTER'
			name = messageArgs[0]
			@handleRegistration name, connection, false
		else if messageCommand == 'REGISTER_SPECTATOR'
			name = messageArgs[0]
			@handleRegistration name, connection, true
		else
			player = @playerFor connection
			player?.handleMessage messageCommand, messageArgs

	handleRegistration: (name, connection, isSpectator) ->
		newPlayer = @createPlayer name, connection
		unless @isValidName name
			newPlayer.registrationRejected 'INVALID_NAME'
		else if @nameIsTakenByAnotherPlayer name, connection
			newPlayer.registrationRejected 'NAME_ALREADY_TAKEN'
		else
			@addPlayer connection, newPlayer, isSpectator

	isValidName: (name) ->
		name != '' and name.length <= 20 and not /[,;:\s]/.test name

	nameIsTakenByAnotherPlayer: (name, connection) ->
		existingPlayer = @findPlayerByName(name)
		existingPlayer? and not connection.belongsTo existingPlayer

	findPlayerByName: (name) ->
		for key, player of @players
			return player if player.name == name

	shutDown: (callback) ->
		@udpSocket.close()
		@webSocket.server.close(callback)

	playerFor: (connection) ->
		@players[connection.id]
	
	addPlayer: (connection, player, isSpectator) ->
		@players[connection.id] = player
		if isSpectator
			@game.registerSpectator player
		else
			@game.registerPlayer player
		player.registered()

	createPlayer: (name, connection) ->
		connection.createPlayer name

	class Connection
		constructor: (address, @socket) ->
			@host = address.address
			@port = address.port
			@id = "#{@host}:#{@port}"

		toString: => @id

		belongsTo: (player) =>
			player.remoteHost == @host

		createPlayer: (name) =>
			player = remotePlayer.create name, (message) =>
				log "sending '#{message}' to #{name} (#{@id})"
				@send message
				player.remoteHost = @host

	class UdpConnection extends Connection
		send: (message) =>
			buffer = new Buffer(message)
			@socket.send buffer, 0, buffer.length, @port, @host

	class WebSocketConnection extends Connection
		send: (message) =>
			@socket.send message

exports.start = (game, port, callback) ->
	return new Server game, port, callback
