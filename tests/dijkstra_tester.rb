require_relative '../graph_builder.rb'
require_relative '../dijkstra_executor.rb'

#TODO use unit testing instead

graph = GraphBuilder.new

n1 = GraphBuilder::GraphNode.new('n1', '10.0.0.1')
n2 = GraphBuilder::GraphNode.new('n2', '10.0.0.2')
n3 = GraphBuilder::GraphNode.new('n3', '10.0.0.3')

puts "no edges"
DijkstraExecutor.routing_table(graph, n1).print_routing
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0

graph.add_edge(n1, n2, 1)
graph.add_edge(n2, n3, 1)

puts "linear path to n3"
DijkstraExecutor.routing_table(graph, n1).print_routing
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0
# destination: n2 => next hop: n2 distance: 1
# destination: n3 => next hop: n2 distance: 2

graph.add_edge(n3, n1, 1)

puts "cyclic"
DijkstraExecutor.routing_table(graph, n1).print_routing
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0
# destination: n2 => next hop: n2 distance: 1
# destination: n3 => next hop: n3 distance: 1


graph.remove_edge(n3, n1)
graph.add_edge(n3, n1, 2)

puts "cyclic with 2 possible paths to n3"
DijkstraExecutor.routing_table(graph, n1).print_routing
#One possible solution (could also go through n2)
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0
# destination: n2 => next hop: n2 distance: 1
# destination: n3 => next hop: n3 distance: 2

graph.remove_edge(n3, n1)
graph.add_edge(n3, n1, 3)

puts "cyclic with faster indirect path to n3"
routing_table = DijkstraExecutor.routing_table(graph, n1).print_routing
# Avoid routing through n3 directly. Go through n2
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0
# destination: n2 => next hop: n2 distance: 1
# destination: n3 => next hop: n2 distance: 2

puts "Print routing table"
puts routing_table.inspect #type Hash of hostnames to RouteEntries

#How to get the source node and relevant info
source = routing_table.get_source
puts source.inspect #type RouteNode
puts source.hostname == "n1"
puts source.ip == "10.0.0.1"

#How to get a RouteEntry for a hostname and relevant info
n3_entry = routing_table["n3"]
puts n3_entry.inspect #type RouteEntry
puts n3_entry.distance == 2
puts n3_entry.destination.hostname == "n3"
puts n3_entry.destination.ip == "10.0.0.3"
puts n3_entry.next_hop.hostname == "n2"
puts n3_entry.next_hop.ip == "10.0.0.2"

n4 = GraphBuilder::GraphNode.new('n4', '10.0.0.4')
n5 = GraphBuilder::GraphNode.new('n5', '10.0.0.5')
n6 = GraphBuilder::GraphNode.new('n6', '10.0.0.6')
n7 = GraphBuilder::GraphNode.new('n7', '10.0.0.7')

graph.add_edge(n4, n5, 1)
graph.add_edge(n5, n6, 1)
graph.add_edge(n6, n7, 1)
graph.add_edge(n7, n4, 1)

puts "Disjoint networks"

DijkstraExecutor.routing_table(graph, n1).print_routing
# Disjoint network: n4 is not reachable from n1.
# D, [2015-11-20T19:49:46.263444 #29449] DEBUG -- : Disjoint network: n5 is not reachable from n1.
# D, [2015-11-20T19:49:46.263467 #29449] DEBUG -- : Disjoint network: n6 is not reachable from n1.
# D, [2015-11-20T19:49:46.263547 #29449] DEBUG -- : Disjoint network: n7 is not reachable from n1.
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0
# destination: n2 => next hop: n2 distance: 1
# destination: n3 => next hop: n2 distance: 2

DijkstraExecutor.routing_table(graph, n5).print_routing


graph.add_edge(n4, n6, 1) #faster to go from n4 to n6

puts "cross from n4 to n6"
DijkstraExecutor.routing_table(graph, n4).print_routing


puts "bad cross from n4 to n6"
graph.remove_edge(n4, n6)
graph.add_edge(n4, n6, 10) #Faster to go through n5
DijkstraExecutor.routing_table(graph, n4).print_routing


graph.add_edge(n5, n7, 1)

puts "cross from n5 to n7"
DijkstraExecutor.routing_table(graph, n5).print_routing

puts "connect disjoint"
graph.add_edge(n2, n4, 5)
DijkstraExecutor.routing_table(graph, n1).print_routing

graph.add_edge(n7, n1, 5)
DijkstraExecutor.routing_table(graph, n1).print_routing

graph = GraphBuilder.new

n1 = GraphBuilder::GraphNode.new('n1', '10.0.0.1')
n2 = GraphBuilder::GraphNode.new('n2', '10.0.0.2')
n3 = GraphBuilder::GraphNode.new('n3', '10.0.0.3')
n4 = GraphBuilder::GraphNode.new('n4', '10.0.0.4')

puts "s1 copy"
graph.add_edge(n1, n2, 1)
graph.add_edge(n2, n4, 1)
graph.add_edge(n4, n3, 1)
graph.add_edge(n3, n1, 1)
graph.add_edge(n2, n3, 1)

DijkstraExecutor.routing_table(graph, n1).print_routing

