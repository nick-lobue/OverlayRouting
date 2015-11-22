require 'socket'
#run on n1 in CORE
server = TCPServer.new 5000 # Server bound to port 2000

loop do
  client = server.accept    # Wait for a client to connect
  puts client.gets
  client.puts "Here a message!!!"
  client.close
end