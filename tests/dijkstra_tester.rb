require_relative '../graph_builder.rb'
require_relative '../dijkstra_executor.rb'



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
DijkstraExecutor.routing_table(graph, n1).print_routing
# Avoid routing through n3 directly. Go through n2
# Routing table for: n1
# destination: n1 => next hop: n1 distance: 0
# destination: n2 => next hop: n2 distance: 1
# destination: n3 => next hop: n2 distance: 2

#TODO test empty graph
#DijkstraExecutor.routing_table Graph.new