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
		#GraphNode.hostname => GraphNode
		@graph = Hash.new
		@sequenceNumber = 0

	end

	# ----------------------------------
	# Holds information about a
	# node in the graph.
	# ----------------------------------
	class GraphNode

		# -------------------------------------------------------------
		# Initializes the instance variables for a 
		# graph node.
		# @param hostName Specifies this node's hostname.
		# @param ipAddress Specifies the node's ip.
		# @param neighbors Provides the set of edges from this node.
		# -------------------------------------------------------------
		def initialize(hostName, ipAddress, neighbors = nil)
			@hostName = hostName
			@ipAddress = ipAddress
			@neighbors = neighbors

			#used for dijkstras
			@distance = nil
			@parent = nil

			#If it is directly connected to s then s can forward to this node
			#Even if this is true it might be possible that s doesn't route to this ever
			#Might not need this field
			@is_forward_node = false

			#The GraphNode from which a source node will have to forward to 
			#if it wants to reach this node
			#e.g. network: S -> A -> D if S is the source then GraphNode D
			#will have A as it's forward node.
			#Used to construct routing table.
			@forward_node = nil
		end

		# -----------------------------------------
		# Override equals method to compare two
		# nodes by hostname and ip address.
		# -----------------------------------------
		def eql?(otherNode)
			return self.hostName == otherNode.hostName && self.ipAddress == otherNode.ipAddress
		end

		
		# setters/getters
		attr_accessor :hostName, :ipAddress, :neighbors

	end

	# ----------------------------------
	# Holds information about an
	# edge within the graph.
	# ----------------------------------
	class GraphEdge

		# -------------------------------------------------------------------
		# Initializes the instance variables for a 
		# graph edge. The endNode is the node that 
		# connects to the other side of the edge.
		# @param endNode GraphNode containing the other node in this edge.
		# @param edgeCost Number specifying cost of the edge.
		# -------------------------------------------------------------------
		def initialize(endNode, edgeCost = 0)
			@endNode = endNode
			@edgeCost = edgeCost
		end

		# -------------------------------------------------
		# Override equals method to call equals method
		# of the GraphNode object to compare end nodes.
		# -------------------------------------------------
		def eql?(otherEdge)
			return self.endNode.eql?(otherEdge.endNode)
		end

		# setters/getters
		attr_accessor :endNode, :edgeCost

	end


	# --------------------------------------------------------------------
	# Adds a new edge to the graph hash table.
	# If the startNode's hostname is already a key,
	# then the edge is added to its neighbors
	# collection. Otherwise, a new hash entry is inserted.
	# @param startNode GraphNode containing the start node of the edge.
	# @param endNode GraphNode holding the end node of the edge.
	# @param edgeCost Number specifies the cost of the edge.
	# @return self for chaining calls.
	# --------------------------------------------------------------------
	def addEdge(startNode, endNode, edgeCost)
		newEdge = GraphEdge.new(endNode, edgeCost)

		#TODO Nick shouldn't you add the edge to endNode
		#Or are you doing it somewhere else?

		if @graph[startNode.hostName] == nil
			startNode.neighbors = Set.new([newEdge])
			@graph[startNode.hostName] = startNode
		else
			@graph[startNode.hostName] = @graph[startNode.hostName].neighbors.delete(newEdge).add(newEdge)
		end

		return self
	end

	# -----------------------------------------------------------------
	# Removes the edge from the graph hash table that
	# corresponds to startNode --> endNode. If this edge
	# doesn't exist then nothing is changed. Returns self
	# to allow for method chaining.
	# @param startNode GraphNode containing starting node of edge.
	# @param endNode GraphNode containing end node of edge.
	# @return self to allow for method chaining.
	# -----------------------------------------------------------------
	def removeEdge(startNode, endNode)
		if @graph[startNode.hostName] != nil
			@graph[startNode.hostName] = @graph[startNode.hostName].neighbors.delete(GraphEdge.new(endNode))
		end

		return self
	end

	# --------------------------------------------------
	# Adds a new GraphNode object that is provided
	# by newNode to the hash table if it isn't 
	# already in the hash.
	# @param newNode GraphNode holding the new node.
	# @return self for method chaining
	# --------------------------------------------------
	def addNode(newNode)
		if @graph[newNode.hostName] == nil
			@graph[newNode.hostName] = newNode
		end

		return self
	end

	# --------------------------------------------------
	# Deletes the node in the graph hash that 
	# corresponds with the given hostname.
	# @param hostName Hostname of node to delete.
	# @return self for method chaining
	# --------------------------------------------------
	def deleteNode(hostName)
		#TODO Nick: What about edges? Is that handled somewhere else?
		@graph.delete(hostName)

		return self
	end


	def weight(source, destination)
		#TODO this would be faster if I could get GraphNode.neighbors by destination.hostname
	end

	# -------------------------------------------------
	# Returns the GraphNode object associated
	# with the given hostName. If no node exists,
	# then nil is returned.
	# @param hostName Hostname of node to retrieve.
	# @return GraphNode object or nil.
	# -------------------------------------------------
	def getNode(hostName)
		return @graph.fetch(hostName, nil)
	end

	# creates getter for the graph hash
	# and setter/getter for sequence number
	attr_reader :graph
	attr_accessor :sequenceNumber

end