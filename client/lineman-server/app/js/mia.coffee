address = document.domain
port = 9000
# delay to draw the next datapoint
delay = 500
smoothSamples = 50
canvas = null
windowSize = {}
playerColors = {}

#$.removeCookie 'spectatorId'
spectatorId = $.cookie 'spectatorId'
unless spectatorId?
	spectatorId = guid()
$.cookie 'spectatorId', spectatorId, { expires: 7 }
#console.log "ID: #{spectatorId}"

spectatorName = "Spectator#{spectatorId}"

smoothie = new SmoothieChart
	timestampFormatter: SmoothieChart.timeFormatter
	millisPerPixel: 200
	scaleSmoothing: 0.01
	grid:
		millisPerLine: 20000
	yRangeFunction: (range) ->
		min = range.min / 2 - 0.05
		max = range.max * 1.3
		{min, max}

colors = [
	'hsl(30, 100%, 70%)'
	'hsl(210, 100%, 70%)'
	'hsl(120, 100%, 70%)'
	'hsl(300, 100%, 70%)'
	'hsl(75, 70%, 50%)'
	'hsl(255, 100%, 85%)'
	'hsl(165, 90%, 80%)'
	'hsl(345, 100%, 50%)'
]

class Round
	constructor: (@number, @players) ->
		@messages = []
	addMessage: (message) -> @messages.push message

class ScoreSmoother
	store = []

	constructor: (@maxsize) ->

	add: (scores) ->
		if store.length >= @maxsize
			store.shift()
		store.push scores

	last: ->
		store[store.length - 1] ? {}

	first: ->
		store[0] ? {}

	getAverageScores: ->
		lastScores = @last()
		averages = {}
		for name, score of lastScores
			averages[name] = (score - (@first()[name] ? 0)) / (store.length - 1)
		averages

class Scores
	scoreSmoother = new ScoreSmoother smoothSamples
	lastTime = 0;
	timeSeries = {}
	currentScores: {}

	# scoreInfo is a string like 'name1:score1,name2:score2'
	track: (scoreInfo) =>
		playerScoresStrings = scoreInfo.split ','
		currentTime = (new Date).getTime()
		playerScores = {}
		for nameScore in playerScoresStrings
			[name, score] = nameScore.split ':'
			playerScores[name] = score
		@currentScores = playerScores

		# Only save score if delay has gone by since the last time
		if currentTime - delay >= lastTime
			scoreSmoother.add playerScores
			lastTime = currentTime
			averageScores = scoreSmoother.getAverageScores()
			for name, score of averageScores
				unless timeSeries[name]?
					playerColors[name] = colors[Object.keys(timeSeries).length]
					# console.log "#{name}: #{playerColors[name]}"
					timeSeries[name] = new TimeSeries
					smoothie.addTimeSeries timeSeries[name], lineWidth: '5', strokeStyle: playerColors[name]
				timeSeries[name].append currentTime, score

currentRound = new Round
lastRound = new Round
scores = new Scores

COMMANDS =
	'ROUND STARTED': (message, parts) ->
		lastRound = currentRound
		currentRound = new Round(parts[1], parts[2])
		currentRound.addMessage message
	'SCORE': (message, parts) ->
		scores.track parts[1]

renderLastRound = ->
	$list = $('<ul>')
	for message in lastRound.messages
		$list.append "<li>#{message}</li>"
		$('#last-round').empty()
		$('#last-round').append($list)


handleMessage = (message) ->
	messageParts = message.split ';'
	command = messageParts[0]
	if COMMANDS[command]?
		COMMANDS[command](message, messageParts)
	else
		currentRound.addMessage message

start = (conf) ->
	url = "http://#{conf.address}:#{conf.port}"
	socket = io.connect url
	socket.on 'connect', -> connected(register)
	socket.on 'disconnect', disconnected
	socket.on 'message', handleMessage

	connected = (callback) ->
		showState 'Connected'
		callback()
	disconnected = ->
		showState ''
	showState = ->
		$('#server-state').text('Connected')

	register = ->
		socket.send "REGISTER_SPECTATOR;#{spectatorName}"

	canvas = document.getElementById("score-chart")
	smoothie.streamTo canvas, delay

renderScores = ->
	sortScores = []
	for name, score of scores.currentScores
		sortScores.push {name, score}

	sortScores.sort (a, b) -> a.score < b.score

	$list = $('<ul>')
	for entry in sortScores
		color = playerColors[entry.name]
		$list.append "<li><span style=\"color:#000; background-color: #{color}; width:1em; display:inline-block\">&nbsp;</span> #{entry.name}: #{entry.score}</li>"
		$('#player-list').empty()
		$('#player-list').append($list)

adaptCanvas = ->
	return if windowSize.height is window.innerHeight and windowSize.width is window.innerWidth
	windowSize =
		height: window.innerHeight
		width: window.innerWidth
	canvas.width = windowSize.width * 0.5
	canvas.height = windowSize.height * 0.8

setInterval adaptCanvas, 500
setTimeout renderLastRound, 1000
setInterval renderLastRound, 10000
setInterval renderScores, 1000

window.mia = {
	address
	port
	start
}
