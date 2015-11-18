require 'set'

class MinHeap
	#Not really a min heap but using as a place holder until I need to
	@heap = nil

	def initialize(heap)
		@heap = heap
	end

	#Slow O(n) implementation
	#removes and returns GraphNode with minimum 
	def extract_min

		min_node = nil
		min_distance = -1

		@heap.each{|node|
			if node.distance > min_distance
				#found new min node
				min_node = node
				min_distance = node.distance
			end
		}

		delete(min_node)

		return min_node
	end

	def empty?
		@heap.empty?
	end

	def delete!(node)
		@heap = @heap.delete node
	end
end


#set of final shortest-path weights
class DijkstraExecutor


	#runs dijkstra on Graph. Based on CLRS pseudocode
	#Warning do not run on an already computed graph
	def dijkstra(graph, source)
		
		if source.class == "String"
			#get GraphNode by hostname
			source = graph.getNode(source)
		elif source.class != "GraphNode"
			#source param must be of type GraphNode or String
			throw :invalidArgument
		end

		#Source distance is 0 since we are starting from here
		source.distance = 0

		#Finished set
		s = Set.new

		q = MinHeap.new(graph.values)

		until q.empty?
			u = MinHeap.extract_min

			s.push(u)

			u.neighbors.each{ |v|
				#relax u to v if possible
				#
			}

		end


		#Ending state:
		#Each node has a parent pointer that eventually leads back to s
		#a distance that gets the total weight from s
		
		#TODO itterate from each node back to s. if ittNode.parent == s 
		#then set RoutingTable[node.hostname] => ittNode.hostname
		#Performance Problem with that solution.  Linear network of 5 nodes requires
		#4 + 3 + 2 + 1 itterations 
		#Can I form the tree while doing dijkstra?
		#Since u in dijkstra cannot be relaxed any furthur maybe I could set 
	end

	#If recomputing dijkstra on a graph that has already been computed on
	#This will need to run to clear any values used in computation
	#Note: I don't think we ever need to recompute this 
	def clear_dijkstra(graph)
	end

end