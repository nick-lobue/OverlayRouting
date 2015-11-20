require 'socket'
#run on n1 in CORE
server = TCPServer.new 5000 # Server bound to port 2000

loop do
  client = server.accept    # Wait for a client to connect
  client.puts "Hello !"
  client.puts "Time is #{Time.now}"
  client.close
end