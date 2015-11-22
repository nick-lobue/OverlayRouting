require 'logger'

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
  	while true
    	#TODO pass in params correctly. Currently using this against a TCP Server
    	flood = FloodingUtil.new(ARGV[1], ARGV[2], ARGV[3], "./pa3.r-scenarios/s1/weights.csv")
    	$log.info "flood returned #{flood.inspect}"
    	#Need this to confirm thread is finished or to know thread got an exception

    	#print response 
    	echo_server = TCPServer.new ARGV[3]
    	client = server.accept
    	$log.info client.gets
    	client.close
    	echo_server.close
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