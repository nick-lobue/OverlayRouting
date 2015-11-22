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

  $log.debug "debug mode host #{ARGV[1]} ip:host #{ARGV[2]}:#{ARGV[3]}"

  flood_thread = Thread.new {

    flood = FloodingUtil.new(ARGV[1], ARGV[2], ARGV[3], "./pa3.r-scenarios/s1/weights.csv")

    #flood network with initial Link State Packet
    flood.initial_flood

    #listens for LSP
    server = TCPServer.new ARGV[3]

    # a queue of LinkStatePackets received from server
    lsp_queue = []

  	while true
      # #TODO pass in params correctly. Currently using this against a TCP Server
      # flood = FloodingUtil.new(ARGV[1], ARGV[2], ARGV[3], "./pa3.r-scenarios/s1/weights.csv")
      # $log.info "flood returned #{flood.inspect}"
      # lsp_received.wait flood_mutex # wait until link state packet received

      client = server.accept

      while (packet = server.gets)
        #TODO Need to differentiate link state packets and control packets here. Assuming I'm only getting LSP for now
        $log.info "received link state packet: #{packet}"

        #convert packet from json to LinkStatePacket
        lsp_queue.push LinkStatePacket.from_json(packet)

      end

      #No more packets
      client.close

      #Process all link state packets from the client
      until lsp_queue.empty? do
        flood.check_link_state_packet(lsp_queue.pop)
      end


  	end
  }

  flood_thread.join

  abort("In debug mode")

end

if ARGV[0] == "debug"
  $debug = true
  debug_flood 
end

#Call on Flooding Utility to create link state packets and carry out flooding
flood_thread = Thread.new {
  #TODO pass in params correctly. Currently using this against a TCP Server
  flood = FloodingUtil.new("n1", "10.0.0.20", 4000, "./pa3.r-scenarios/s1/weights.csv")
  $log.info "flood returned #{flood.inspect}"
}

#Need this to confirm thread is finished or to know thread got an exception
flood_thread.join