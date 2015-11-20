require 'graph_builder.rb'
require 'dijkstra_executor.rb'

graph = Graph.new
n1 = GraphNode.new('n1', '')

#TODO test empty graph
#DijkstraExecutor.routing_table Graph.new