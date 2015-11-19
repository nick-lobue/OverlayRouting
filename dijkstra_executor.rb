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

#ip and hostname of a Routing Node
RouteNode = struct.new(:ip, :hostname)

class RoutingInfo
	:attr_accessor :source, :destination, :next_hop, :distance

	def initialize(source, destination, next_hop, distance)
		@source = source
		@destination = destination
		@next_hop = next_hop
		@distance = distance
	end
end

#set of final shortest-path weights
class DijkstraExecutor

	#runs dijkstra on Graph. Based on CLRS pseudocode
	#Warning do not run on an already computed graph
	def self.routing_table(graph, source)
		routing_table = Hash.new

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

			#Since u is in S. The shortest path to u is found
			unless u.equal? source
				if u.parent.equal? source
					#directly connected to source and the directly going from 
					#source to u is the shortest path
					routing_table[u.hostName] = u.hostName
					u.forward_node = u
					u.is_forward_node = true
				else
					#Assumption parent should already be in s since the 
					#shortest path should include s.parent that is source -> u.parent -> u
					#TODO verify if this is true
					
					routing_table[u.hostName] = u.hostName
					u.forward_node = u.parent.forward_node

					unless s.includes?(v.parent)
						#Made an incorrect assumption
						throw :parentNotInPath
					end
				end
			end

			#relax all neighbors
			u.neighbors.each{ |v|
				
				relax_distance = u.distance + graph.weight(s, d)
				
				if v.distance.nil? or v.distance > relax_distance
					v.distance = relax_distance
					v.parent = u
				end

			}

		end

		clear_dijkstra graph

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

	#TODO
	def self.clear_dijkstra(graph)
	end

end