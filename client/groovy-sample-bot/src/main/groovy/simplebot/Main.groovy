/**
 * 
 */
package simplebot

/**
 * @author ascheman
 *
 */
class Main {
	
	static class Client {
		String server = 'localhost'
		int port = 9000
		String alias = 'groovy-bot'
		
		private DatagramSocket socket
		private InetAddress addr
		
		Client () {
		}
		
		void register () {
			socket = new DatagramSocket ()
			socket.setSoTimeout(30000) // block for no more than 30 seconds
			addr = InetAddress.getByName(server)
			
			String registerMsg = "REGISTER;${alias}"
			send (registerMsg)
		}
		
		void send (String msg) {
			def packet = new DatagramPacket(msg.bytes, msg.length(), addr, port)
			socket.send(packet)
		}
		
		String receive () {
			def buffer = (' ' * 4096) as byte[]
			def response = new DatagramPacket(buffer, buffer.length)
			socket.receive(response)
			def s = new String(response.data, 0, response.length)
			println "Server said: '$s'"
	
			return s
		}
	}
	
	static class Player {
		Client client
		
		String token
		
		Player (Client client) {
			this.client = client
		}
		
		void receiveAndHandle () {
			String msg = client.receive()

			String[] splitted = msg.split(";")
			String cmd = splitted[0]

			switch (cmd) {
				case "ROUND STARTING":
					token = splitted[1]
					client.send ("JOIN;${token}")
					println "Joined: $token"
					break
				case "YOUR TURN":
					String currentToken = splitted[1]
					client.send ("ROLL;$currentToken")
					break
				case "ROLLED":
					String dice = splitted[1]
					String currentToken = splitted[2]
					client.send ("ANNOUNCE;6,6;$currentToken")
					break
			}
		}
	}
	
	static main(args) {
		def server = args[0] ?: "localhost"
		int port = Integer.valueOf(args[1] ?: 9000)
		def alias = args[2] ?: "groovy-bot"

		Client client = new Client (server : server, port : port, alias : alias)
		client.register()
		client.receive()
		
		Player player = new Player (client)
		
		while (true) {
			player.receiveAndHandle()
		}
		
	}

}
