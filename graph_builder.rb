require 'set'

# ----------------------------------------------------
# Used to build a graph to represent the topology
# of the network and contains information needed
# to determine shortest paths.
# ----------------------------------------------------
class GraphBuilder

	# ---------------------------------------------------
	# Create the hash that will be used to represent 
	# the graph structure. Keys are hostnames of the
	# nodes and the values are GraphNode objects
	# containing additional information. Also create
	# a sequence number that will be used to determine
	# if and how many times a graph has been updated.
	# ---------------------------------------------------
	def initialize()
		@graph = Hash.new
		@sequence_number = 0
	end

	# ----------------------------------
	# Holds information about a
	# node in the graph.
	# ----------------------------------
	class GraphNode

		# -------------------------------------------------------------
		# Initializes the instance variables for a 
		# graph node.
		# @param host_name Specifies this node's hostname.
		# @param ip_address Specifies the node's ip.
		# @param neighbors Provides the set of edges from this node.
		# -------------------------------------------------------------
		def initialize(host_name, ip_address, neighbors = nil)
			@host_name = host_name
			@ip_address = ip_address
			@neighbors = neighbors
		end

		# -----------------------------------------
		# Override equals method to compare two
		# nodes by hostname and ip address.
		# -----------------------------------------
		def eql?(otherNode)
			return self.host_name == otherNode.host_name && self.ip_address == otherNode.ip_address
		end

		
		# setters/getters
		attr_accessor :host_name, :ip_address, :neighbors

	end

	# ----------------------------------
	# Holds information about an
	# edge within the graph.
	# ----------------------------------
	class GraphEdge

		# --------------------------------------------------------------------
		# Initializes the instance variables for a 
		# graph edge. The end_node is the node that 
		# connects to the other side of the edge.
		# @param end_node GraphNode containing the other node in this edge.
		# @param edge_cost Number specifying cost of the edge.
		# --------------------------------------------------------------------
		def initialize(end_node, edge_cost = 0)
			@end_node = end_node
			@edge_cost = edge_cost
		end

		# -------------------------------------------------
		# Override equals method to call equals method
		# of the GraphNode object to compare end nodes.
		# -------------------------------------------------
		def eql?(other_edge)
			return self.end_node.eql?(other_edge.end_node)
		end

		# setters/getters
		attr_accessor :end_node, :edge_cost

	end


	# --------------------------------------------------------------------
	# Adds a new edge to the graph hash table.
	# If the start_node's hostname is already a key,
	# then the edge is added to its neighbors
	# collection. Otherwise, a new hash entry is inserted. Therefore,
	# this can be called even if nodes provided aren't currently in
	# the graph because this function will insert them.
	# @param start_node GraphNode containing the start node of the edge.
	# @param end_node GraphNode holding the end node of the edge.
	# @param edge_cost Number specifies the cost of the edge.
	# @return self for chaining calls.
	# --------------------------------------------------------------------
	def add_edge(start_node, end_node, edge_cost)
		start_node = @graph[start_node.host_name] if @graph[start_node.host_name] != nil
		end_node = @graph[end_node.host_name] if @graph[end_node.host_name] != nil

		# create edges using nodes and cost provided
		new_edge_1 = GraphEdge.new(end_node, edge_cost)
		new_edge_2 = GraphEdge.new(start_node, edge_cost)

		# add new edge to starting node
		if @graph[start_node.host_name] == nil
			start_node.neighbors = Set.new([new_edge_1])
			@graph[start_node.host_name] = start_node
		else
			@graph[start_node.host_name].neighbors.delete(new_edge_1).add(new_edge_1)
		end

		# add new edge to end node
		if @graph[end_node.host_name] == nil
			end_node.neighbors = Set.new([new_edge_2])
			@graph[end_node.host_name] = end_node
		else
			@graph[end_node.host_name].neighbors.delete(new_edge_2).add(new_edge_2)
		end

		return self
	end

	# -----------------------------------------------------------------
	# Removes the edge from the graph hash table that
	# corresponds to start_node --> end_node. If this edge
	# doesn't exist then nothing is changed. Returns self
	# to allow for method chaining.
	# @param start_node GraphNode containing starting node of edge.
	# @param end_node GraphNode containing end node of edge.
	# @return self to allow for method chaining.
	# -----------------------------------------------------------------
	def remove_edge(start_node, end_node)
		if @graph[start_node.host_name] != nil && @graph[end_node.host_name] != nil
			@graph[start_node.host_name].neighbors.delete(GraphEdge.new(end_node))
			@graph[end_node.host_name].neighbors.delete(GraphEdge.new(start_node))
		end

		return self
	end

	# --------------------------------------------------
	# Adds a new GraphNode object that is provided
	# by new_node to the hash table if it isn't 
	# already in the hash.
	# @param new_node GraphNode holding the new node.
	# @return self for method chaining
	# --------------------------------------------------
	def add_node(new_node)
		if @graph[new_node.host_name] == nil
			@graph[new_node.host_name] = new_node

			# add edges to neighbors
			if new_node.neighbors != nil
				new_node.neighbors.each { |edge|
					if @graph[edge.end_node.host_name] != nil
						self.addEdge(new_node, @graph[edge.end_node.host_name], edge.edge_cost)
					else
						self.addEdge(new_node, edge.end_node, edge.edge_cost)
					end
				}
			end
		end

		return self
	end

	# --------------------------------------------------
	# Deletes the node in the graph hash that 
	# corresponds with the given hostname.
	# @param host_name Hostname of node to delete.
	# @return self for method chaining
	# --------------------------------------------------
	def delete_node(host_name)
		if @graph[host_name] != nil
			@graph[host_name].neighbors.each { |edge|
				@graph[edge.end_node.host_name].neighbors.delete(GraphEdge.new(@graph[host_name]))
			}
		end

		# delete itself in the graph
		@graph.delete(host_name)

		return self
	end

	# -------------------------------------------------
	# Returns the GraphNode object associated
	# with the given host_name. If no node exists,
	# then nil is returned.
	# @param host_name Hostname of node to retrieve.
	# @return GraphNode object or nil.
	# -------------------------------------------------
	def get_node(host_name)
		return @graph.fetch(host_name, nil)
	end

	# ----------------------------------------------------------
	# Replaces the old topology in the global topology
	# graph by the new topology.
	# @param source_hostname Hostname of node that changed.
	# @param source_ip Ip address of the node being changed.
	# @param new_topology Newly updated local topology.
	# @param old_topology Old version of the local topology.
	# @return self for method chaining.
	# ----------------------------------------------------------
	def replace_sub_topology(source_hostname, source_ip, new_topology, old_topology)
		source_node = GraphNode.new(source_hostname, source_ip)

		# removing all edges associated with the old topology
		if @graph[source_hostname] != nil
			old_topology.each { |(host_name, ip), cost|
				self.remove_edge(source_node, GraphNode.new(host_name, ip))
			}
		end

		# adding all new edges for the new topology
		new_topology.each { |(host_name, ip), cost|
			self.add_edge(source_node, GraphNode.new(host_name, ip), cost)
		}

		return self
	end


	# creates getter for the graph hash
	# and setter/getter for sequence number
	attr_reader :graph
	attr_accessor :sequence_number

end