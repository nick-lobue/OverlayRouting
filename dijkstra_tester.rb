require_relative 'graph_builder.rb'
require_relative 'dijkstra_executor.rb'



graph = GraphBuilder.new

n1 = GraphBuilder::GraphNode.new('n1', '10.0.0.1')
n2 = GraphBuilder::GraphNode.new('n2', '10.0.0.2')
n3 = GraphBuilder::GraphNode.new('n3', '10.0.0.3')

puts "no edges"
DijkstraExecutor.routing_table(graph, n1).print_routing

graph.add_edge(n1, n2, 1)
graph.add_edge(n2, n3, 1)

puts "linear"
DijkstraExecutor.routing_table(graph, n1).print_routing

graph.add_edge(n3, n1, 1)

puts "cyclic"
DijkstraExecutor.routing_table(graph, n1).print_routing

#TODO test empty graph
#DijkstraExecutor.routing_table Graph.new