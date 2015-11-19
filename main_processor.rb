require 'link_state_packet'
require 'graph_builder'
require 'flooding_utility'
require 'dijkstra_executor'
require 'time'
require 'socket'


# --------------------------------------------
# Holds the operations needed to combine
# all aspects of the program.
# --------------------------------------------
class MainProcessor

	# regex constants for user commands
	DUMPTABLE = "^DUMPTABLE\s+(.+)$"
	FORCEUPDATE = "^\s*FORCEUPDATE\s*$"
	CHECKSTABLE = "^\s*CHECKSTABLE\s*$"
	

	# -----------------------------------------------------
	# Creates instance variables needed for routing
	# table construction.
	# -----------------------------------------------------
	def initialize(arguments)
		@node_time = Time.now
		@source_hostname = arguments[0]
		@weights_config_filename = arguments[1]
		@flooding_utility = FloodingUtil.new(source_hostname, @weights_config_filename, arguments[2])
		@routing_table = nil
		@routing_table_updating = false
		@link_state_socket = TCPServer.open(insert_port_here)
		@control_message_socket = TCPServer.open(insert_port_here)
	end

	# ---------------------------------------------------
	# Constantly updates the node_time variable
	# in order to keep track of this node's
	# system time. This is important for certain
	# control message operations and routing updates.
	# ---------------------------------------------------
	def update_time
		# update the node's system time
	end

	# ---------------------------------------------------------------------
	# Listens for incoming connections in order to handle control
	# message transmissions. Once a control message has arrived, it's
	# task is executed in a separate thread so that the node may still
	# be listening for other messages coming through.
	# ---------------------------------------------------------------------
	def control_message_listener
		loop {
			Thread.start(@control_message_socket.accept) do |otherNode|
				# handle the control messages and perform operations
				# this isn't needed until Part 2
			end
		}
	end

	# ---------------------------------------------------------------------
	# Listens for incoming connections to facilitate link
	# state packet transmission. Once a link state packet has arrived,
	# a new thread is created to handle the operations. Operations
	# include the continuation of the packet being flooded, construction
	# of topological graph, and updates to the routing table.
	# ---------------------------------------------------------------------
	def link_state_packet_listener
		loop {
			Thread.start(@link_state_socket.accept) do |otherNode|
				link_state_packet = LinkStatePacket.from_string(otherNode.gets)

				# flood the received packet, update topology graph, and update routing table
				@flooding_utility.check_link_state_packet(link_state_packet)
				@routing_table_updating = true
				@routing_table = DijkstraExecutor.routing_table(@flooding_utility.global_top.graph, source_hostname)
				@routing_table_updating = false

				otherNode.close
			end
		}
	end

	# --------------------------------------------------------------
	# Perform the DUMPTABLE hook by going through the routing
	# table's entries and writing the source host ip, destination
	# ip, next hop, and total distance from source to destination
	# to a .csv file.
	# @param filename Specifies the name of the file to create.
	# --------------------------------------------------------------
	def perform_dumptable(filename)
		filename = filename + ".csv" if filename !~ /.csv/

		# creating the file and writing 
		# MAY NEED TO CHANGE DEPENDING ON ROUTING TABLE BUILD
		#####################################################
		File.open(filename, "w+") { |file|
			@routing_table.each { |destination, info|
				file.puts("#{@source_hostname},#{info.destIp},#{info.nextHop},#{info.distance}")
			}

			file.close
		}
	end

	# -----------------------------------------------------------------
	# Performs the FORCEUPDATE command by calling the flooding
	# utility to determine if the current node's local topology
	# has changed. If it changed, the flooding utility sends the
	# new link state packet out and reconstruct the global topology
	# graph. Then, the routing table is updated. If the link state
	# packet didn't change this function will do nothing.
	# -----------------------------------------------------------------
	def perform_forceupdate
		packet_changed = @flooding_utility.has_changed(@weights_config_filename)

		if (packet_changed)
			@routing_table_updating = true
			@routing_table = DijkstraExecutor.routing_table(@flooding_utility.global_top.graph, source_hostname)
			@routing_table_updating = false
		end
	end

	# ----------------------------------------------------------------
	# Performs the CHECKSTABLE command by determining if the
	# routing table is currently being updated. If it is, 'no' is
	# printed specifying that the node is unstable. Otherwise,
	# 'yes' is printed showing that the node is stable.
	# ----------------------------------------------------------------
	def perform_checkstable
		if (@routing_table_updating)
			$stdout.puts("no")
		else
			$stdout.puts("yes")
		end
	end

	# -------------------------------------------------
	# Main processing method that creates the
	# threads to perform the various operations that
	# a node has to perform.
	# -------------------------------------------------
	def process
		threads = [ Thread.new { update_time }, 
					Thread.new { control_message_listener }, 
					Thread.new { link_state_packet_listener } ]

		# running infinite loop and reading user commands
		loop {
			inputted_command = gets

			# if stdin contains some text then parse it
			if inputted_command != ""
				if /#{DUMPTABLE}/.match(inputted_command)
					Thread.new { perform_dumptable($1) }
				elsif /#{FORCEUPDATE}/.match(inputted_command)
					Thread.new { perform_forceupdate }
				elsif /#{CHECKSTABLE}/.match(inputted_command)
					Thread.new { perform_checkstable }
				else
					$stderr.puts("Incorrect command was provided.")
				end
			end
		}
	end

end


# run processing function
MainProcessor.new(ARGV).process