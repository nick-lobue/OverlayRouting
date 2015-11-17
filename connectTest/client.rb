require 'socket'

ip = "10.0.0.21"
s = TCPSocket.new ip, 2000

s.gets