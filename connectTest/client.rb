require 'socket'
#run on n2
ip = "10.0.0.20"

s = TCPSocket.new ip, 5000

while line = s.gets # Read lines from socket
  puts line         # and print them
end

s.close             # close socket when done