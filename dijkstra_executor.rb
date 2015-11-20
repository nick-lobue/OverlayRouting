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
RouteNode = Struct.new(:ip, :hostname)

#A routing table where hostnames map to RoutingEntries
#Also a feild for source of type RoutingNode
#e.g. for network n1(10.0.0.1) -> n2(10.0.0.2)-> n3(10.0.0.3) where n1 is source
#source = routing_table.get_source #returns RoutingNode for source
#n3_RE = routing_table["n3"] #returns RoutingEntry for hostname n3
#source.hostname == "n1"
#source.ip == "10.0.0.1"
#n3_RE.destination.hostname == "n3"
#n3_RE.destination.ip == "10.0.0.3"
#n3_RE.next_hop.hostname == "n2"
#n3_RE.distance == 2 #if each edge has weight 1
class RoutingTable < Hash
	attr_accessor :source

	def initialize(source)
		@source = source
	end

	def set_source(source)
		@source = source
	end

	def get_source(source)
		@source
	end
end

class RoutingEntry
	attr_accessor :destination, :next_hop, :distance

	def initialize(destination, next_hop, distance)
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

		#parameter check
		if source.class == "String"
			#get GraphNode by hostname
			source = graph.getNode(source)
		elif source.class != "GraphNode"
			#source param must be of type GraphNode or String
			throw :invalidArgument
		end


		clear_dijkstra graph

		#Source distance is 0 since we are starting from here
		source.distance = 0

		#Prepare empty routing table with only information about source
		routing_table = RoutingTable.new
		source_routing_node = RoutingNode.new source.ipAddress, source.hostName
		routing_table.set_source source_routing_node

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
					
					u.next_hop = u

					u.is_forward_node = true
				else
					#Parent should already be in s since the 
					#shortest path should include s.parent that is source -> u.parent -> u

					u.next_hop = u.parent.next_hop

					unless s.includes?(v.parent)
						#Something is wrong in implementation or assumption
						throw :parentNotInPath
					end
				end

				#contruct routing entry where destination is u and next hop is u.next_hop
				destination_route_node = RoutingNode.new u.hostName, u.ipAddress
				next_hop_route_node = RoutingNode.new u.next_hop.hostname, u.next_hop.ipAddress
				routing_entry = RoutingEntry.new destination_route_node, next_hop_route_node, u.distance

				routing_table[u.hostName] = routing_entry

			end

			#relax all neighbors
			u.neighbors.each{ |v|
				
				relax_distance = u.distance + graph.weight(s, d)
				
				#relax is relax distance is less than v.distance or if v.distance DNE
				if v.distance.nil? or v.distance > relax_distance
					v.distance = relax_distance
					v.parent = u
				end

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

	#TODO clear distances, weights, 
	def self.clear_dijkstra(graph)
	end

end