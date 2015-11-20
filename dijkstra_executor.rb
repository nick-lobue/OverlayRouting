require 'set'
require 'logger'
$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG


class MinHeap
	#Not really a min heap but using as a place holder until I need to
	@heap = nil

	def initialize(heap)
		@heap = heap
	end

	#Slow O(n) implementation
	#removes and returns GraphNode with minimum distance
	def extract_min

		min_node = @heap.first #use first as default
    if min_node.nil?
      nil #no node exists
    end
		min_distance = min_node.distance

		@heap.each{|node|
      unless node.distance.nil?
        if node.distance < min_distance
          #found new min node
          min_node = node
          min_distance = node.distance
        end
      end

		}

		delete!(min_node)

		min_node
  end

  def include?(node)
    @heap.include? node
  end

	def empty?
		@heap.empty?
	end

	def delete!(node)
		@heap.delete node
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

	def get_source()
		@source
  end

  def print_routing
    puts "Routing table for: #{self.get_source.hostname}"
    self.each_pair { |destination_hostname, route_entry|
      puts "destination: #{destination_hostname} => next hop: #{route_entry.next_hop.hostname} distance: #{route_entry.distance}"
    }
  end

end

class RouteEntry
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

		#Prepare routing table with only routing from source to source
		source_routing_node = RouteNode.new source.ip_address, source.host_name
		routing_table = RoutingTable.new source_routing_node

    #source.hostname => source Route Entry
    source_routing_entry = RouteEntry.new(source_routing_node, source_routing_node, 0)
    routing_table[source_routing_node.hostname] = source_routing_entry

		#Finished set TODO consider deletion
		completed = Set.new

		not_processed = MinHeap.new(graph.graph.values)

    $log.debug not_processed.inspect

		until not_processed.empty?
			curr_node = not_processed.extract_min

			completed.add(curr_node)

      $log.debug "Extracted: #{curr_node.host_name}"

			#Since curr_node is in completed. The shortest path to curr_node is already found
			unless curr_node.equal? source
				if curr_node.parent.equal? source
					#directly connected to source and the directly going from 
					#source to curr_node is the shortest path
					curr_node.next_hop = curr_node
					curr_node.is_forward_node = true

				else
					#Parent should already be in completed since the
					#shortest path should include curr_node.parent that is source -> curr_node.parent -> curr_node
					curr_node.next_hop = curr_node.parent.next_hop

				end

				#contruct routing entry where destination is curr_node and next hop is curr_node.next_hop
				destination_route_node = RouteNode.new curr_node.ip_address, curr_node.host_name
				next_hop_route_node = RouteNode.new curr_node.next_hop.ip_address, curr_node.next_hop.host_name
				routing_entry = RouteEntry.new destination_route_node, next_hop_route_node, curr_node.distance

				routing_table[curr_node.host_name] = routing_entry

			end

			#relax all neighbors

			curr_node.neighbors.values.each{ |edge|
        neighbor = edge.end_node
				relax_distance = curr_node.distance + graph.weight(curr_node, neighbor)
				
				#relax is relax distance is less than v.distance or if v.distance DNE
				if neighbor.distance.nil? or neighbor.distance > relax_distance

          if(completed.include? neighbor)
            #A node is not supposed to be updated if it is in completed
            throw :updating_node_in_completed
          end

          $log.debug "Updating v: #{neighbor.host_name} old distance #{neighbor.distance} relaxed to #{relax_distance}"
					neighbor.distance = relax_distance
					neighbor.parent = curr_node
				end

			}

		end


		#Ending state:
		#Each node has a parent pointer that eventually leads back to s
		#a distance that gets the total weight from s

    return routing_table
	end

	#TODO clear distances, weights, 
	def self.clear_dijkstra(graph)
  end


end