require 'thread'

#TODO consider deletion. Might not use this. Don't think it is thread safe.

# Maps hostname to forward queues
# hostnames => queue
# Uses Blocking Queues
class MultiSocketQueue
	
	def initialize
		@multi_socket_queue = Hash.new
	end

	#push packet into the queue belonging to the hostname
	#Returns true if a new queue is created
	def push(hostname, packet)
		if hostname.nil? or packet.nil?
			throw :invalid_argument
		end

		#Create new queue
		if multi_socket_queue[hostname].nil?
			multi_socket_queue[hostname] = Queue.new
			create_thread = true
		end

		multi_socket_queue[hostname].push packet

		create_thread
	end

	#Pops packet from hostname's forward queue
	#Will block if 
	def pop(ip, port)
		multi_socket_queue[hostname].pop
	end


end