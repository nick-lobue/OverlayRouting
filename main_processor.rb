require 'logger'
require 'thread'

require_relative 'link_state_packet.rb'
require_relative 'graph_builder.rb'
require_relative 'flooding_utility.rb'
require_relative 'dijkstra_executor.rb'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG



#Time object of the system time at this instance to update
node_time = Time.now


#TODO delete this later
def debug_flood

  Thread.abort_on_exception

  $log.debug "debug mode host #{ARGV[1]} ip:host #{ARGV[2]}:#{ARGV[3]}"

  # a queue of LinkStatePackets received from server
  lsp_queue = []
  lsp_queue_mutex = Mutex.new
  lsp_available = ConditionVariable.new

  #listens for link state packets and puts it in
  lsp_listener = Thread.new {

  	#listens for LSP
    server = TCPServer.new ARGV[3]

    while true

    	$log.debug "before server.accept"
		client = server.accept
		$log.debug "after server.accept"

		lsp_queue_mutex.synchronize {
			$log.debug "in lsp_queue_mutex "

			while (packet = client.gets)

				#TODO Need to differentiate link state packets and control packets here. Assuming I'm only getting LSP for now
				$log.info "received link state packet: #{packet}"

				#convert packet from json to LinkStatePacket
				lsp_queue.push LinkStatePacket.from_json(packet)

			end

			#No more packets from this client
			client.close

			#inform flood thread that they're packets to process
			lsp_available.signal unless lsp_queue.empty?
		}


	end

  }

  flood_thread = Thread.new {

    flood = FloodingUtil.new(ARGV[1], ARGV[2], ARGV[3], "./pa3.r-scenarios/s1/weights.csv")

    #flood network with initial Link State Packet
    flood.initial_flood

  	while true
      # #TODO pass in params correctly. Currently using this against a TCP Server
      # flood = FloodingUtil.new(ARGV[1], ARGV[2], ARGV[3], "./pa3.r-scenarios/s1/weights.csv")
      # $log.info "flood returned #{flood.inspect}"
      # lsp_received.wait flood_mutex # wait until link state packet received


      lsp_queue_mutex.synchronize {

      	#wait until packets are available to process
      	lsp_available.wait(lsp_queue_mutex)

      	lsp = lsp_queue.pop
      	$log.debug "received LSP #{lsp.inspect}"

	    #Process all link state packets from the client
	    until lsp_queue.empty? do
	      flood.check_link_state_packet(lsp)
	    end

	  }

  	end
  }

end

if ARGV[0] == "debug"
  $debug = true
  debug_flood 
  sleep(1000) #not sure why program exits when main dies
end

# #Call on Flooding Utility to create link state packets and carry out flooding
# flood_thread = Thread.new {
#   #TODO pass in params correctly. Currently using this against a TCP Server
#   flood = FloodingUtil.new("n1", "10.0.0.20", 4000, "./pa3.r-scenarios/s1/weights.csv")
#   $log.info "flood returned #{flood.inspect}"
# }

# #Need this to confirm thread is finished or to know thread got an exception
# flood_thread.join