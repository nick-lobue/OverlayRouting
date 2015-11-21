require 'logger'

require_relative 'link_state_packet.rb'
require_relative 'graph_builder.rb'
require_relative 'flooding_utility.rb'
require_relative 'dijkstra_executor.rb'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG

#Time object of the system time at this instance to update
node_time = Time.now


#Call on Flooding Utility to create link state packets and carry out flooding
flood_thread = Thread.new { 
  #TODO pass in 
  flood = FloodingUtil.new("n1", "10.0.0.20", 4000, "./pa3.r-scenarios/s1/weights.csv")
  $log.info "flood returned #{flood.inspect}"
}

#Need this to confirm thread is finished or to know thread got an exception
flood_thread.join