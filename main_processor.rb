require 'link_state_packet'
require 'graph_builder'
require 'flooding_utility'
require 'dijkstra_executor'

#Time object of the system time at this instance to update
node_time = Time.now


#Call on Flooding Utility to create link state packets and carry out flooding
flood_thread = Thread.new { 
  flood = FloodingUtil.new()
  
}
