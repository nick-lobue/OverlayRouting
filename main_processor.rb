require 'time'
require 'socket'
require 'thread'

require_relative 'packet.rb'
require_relative 'link_state_packet.rb'
require_relative 'control_msg_packet.rb'
require_relative 'graph_builder.rb'
require_relative 'flooding_utility.rb'
require_relative 'dijkstra_executor.rb'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG
$debug = true #TODO set to false on submission

# --------------------------------------------
# Holds the operations needed to combine
# all aspects of the program.
# --------------------------------------------
class MainProcessor

	# regex constants for user commands
	DUMPTABLE = "^DUMPTABLE\s+(.+)$"
	FORCEUPDATE = "^\s*FORCEUPDATE\s*$"
	CHECKSTABLE = "^\s*CHECKSTABLE\s*$"
	SHUTDOWN = "^\s*SHUTDOWN\s*$"

	TRACEROUTE = "^TRACEROUTE\s+(.+)$"
	

	# ------------------------------------------------------
	# Parses through the configuration file to
	# obtain the update interval and the file
	# paths for the other configuration files.
	# @param config_filepath File path for config file.
	# ------------------------------------------------------
	def parse_config_file(config_filepath)
		File.open(config_filepath).each do |line|
			if line =~ /\s*updateInterval\s*=\s*(\d+)\s*/
				@update_interval = $1
			elsif line =~ /\s*weightFile\s*=\s*(.+)\s*/
				@weights_config_filepath = $1
			elsif line =~ /\s*nodes\s*=\s*(.+)\s*/
				@nodes_config_filepath = $1
			end
		end
	end

	# -------------------------------------------------------
	# Extracts the current node's ip address and port
	# number to be used from the given files.
	# @param weights_filepath File path to get ip address.
	# @param ports_filepath File path to get port number.
	# @param node_hostname String for node's host name.
	# -------------------------------------------------------
	def extract_ip_and_port(weights_filepath, ports_filepath, node_hostname)

		File.open(weights_filepath).each do |line|
			if line =~ /#{node_hostname}\s*,\s*([\d\.]+)/
				@source_ip = $1
				break
			end
		end

		File.open(ports_filepath).each do |line|
			if line =~ /\s*#{node_hostname}\s*=\s*(\d+)\s*/
				@source_port = $1
				break
			end
		end
	end

	# -----------------------------------------------------
	# Creates instance variables needed for routing
	# table construction.
	# -----------------------------------------------------
	def initialize(arguments)

		if arguments.length != 2
			puts "Usage: ruby main_processor.rb [config file] [source hostname]"
		end

		@node_time = Time.now
		@config_filepath = arguments[0]
		@source_hostname = arguments[1]

		$log.debug("config_filepath: #{@config_filepath} source_hostname: #{@source_hostname}")

		# parse files to get network information
		parse_config_file(@config_filepath)
		extract_ip_and_port(@weights_config_filepath, @nodes_config_filepath, @source_hostname)

		#A queue containing link state packets
		@lsp_queue = Queue.new

		#A queue containing control message packets
		@cmp_queue = Queue.new

		#A hash to forward queues from hostnames
		@forward_queue = Queue.new

		@port_hash = parse_port @nodes_config_filepath

		@flooding_utility = FloodingUtil.new(@source_hostname, @source_ip, @port_hash, @weights_config_filepath)

		@routing_table = nil
		@routing_table_updating = false
		@link_state_socket = TCPServer.open(@source_port)

    	#flood initial link state packet
    	@flooding_utility.initial_flood
		
		#@control_message_socket = TCPServer.open(@source_port)
	end

	# ---------------------------------------------------
	# Constantly updates the node_time variable
	# in order to keep track of this node's
	# system time. This is important for certain
	# control message operations and routing updates.
	# ---------------------------------------------------
	def update_time
		loop {
			@node_time += 0.001
			sleep(0.001)
		}
	end

	def perform_traceroute(destination_name)

		if destination_name.nil?
			throw :invalid_argument
		end

		payload = Hash.new
		payload['traceroute_data'] = "" #empty string for nodes to append to
		payload["original_source_name"] = @source_hostname
		payload["original_source_ip"] = @source_ip
		control_message_packet = ControlMessagePacket.new(@source_hostname,
				@source_ip, destination_name, nil, 0, "TRACEROUTE", payload)

		#Send to node
		@forward_queue << control_message_packet
	end

	#Handle a traceroute message 
	def handle_traceroute_cmp(control_message_packet)
		#A traceroute message is completed when payload["complete"] is true
		#and payload["original_source_name"] == @source_hostname
		#In that case payload["traceroute_data"] will have our data

		payload = control_message_packet.payload

		if payload["complete"]
			if payload["original_source_name"].eql? @source_hostname
				#TODO Finally at source handle correctly
				$log.debug "Traceroute arrived back #{payload.inspect}"
			else
				#Else data is complete. It is just heading back to original source
				@forward_queue << control_message_packet
			end
			
		else
			payload["traceroute_data"] += "TODO append data for #{@source_hostname}\n"

			#Trace Route has reached destination. Send a new packet to original
			#source with the same data but marked as completed
			if control_message_packet.destination_name.eql? @source_hostname
				payload["complete"] = true
				control_message_packet = ControlMessagePacket.new(@source_hostname,
				@source_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "TRACEROUTE", payload)

			end
			control_message_packet.payload = payload
			@forward_queue << control_message_packet
		end


	end

	# ---------------------------------------------------------------------
	# Listens for incoming connections in order to handle control
	# message transmissions. Once a control message has arrived, it's
	# task is executed in a separate thread so that the node may still
	# be listening for other messages coming through.
	# ---------------------------------------------------------------------
	def control_message_listener

		$log.debug "Started control_message_listener"
		#pop and process all available control message packets
		#will block until packets pushed to queue
		while control_message_packet = @cmp_queue.pop
			$log.debug "Processing #{control_message_packet.inspect}"
			payload = control_message_packet.payload

			if control_message_packet.type.eql? "TRACEROUTE"
				handle_traceroute_cmp control_message_packet
			end
		end
	end

	#Pops  packets and calls check_link_state_packet on each of them
	#After checking all of them it updates the routing table
	#Then it waits until more data is added in the queue
	def link_state_packet_processor
		while link_state_packet = @lsp_queue.pop
			$log.debug "Processing #{link_state_packet.inspect}"

			# flood the received packet, update topology graph, and update routing table
			@flooding_utility.check_link_state_packet(link_state_packet)

			#Optimization: Process additional link state packets but without blocking
			until @lsp_queue.empty?
				@flooding_utility.check_link_state_packet(@lsp_queue.pop)
			end

			@routing_table_updating = true

			#$log.debug "Global topology: #{@flooding_utility.global_top.graph.inspect}"

			@routing_table = DijkstraExecutor.routing_table(@flooding_utility.global_top, @source_hostname)
			$log.info "Routing table updated"
			@routing_table.print_routing if $debug

			@routing_table_updating = false

		end
	end

	#TODO handle link state packets
	#Listens to forward_queue and forwards any new packets to next hop
	def packet_forwarder
		while packet = @forward_queue.pop

			destination_hostname = packet.destination_name

			begin

				#TODO wait until routing table exists and is stable
				#Forward to next hop
				next_hop_route_entry = @routing_table[destination_hostname]

				#TODO create mutex for routing table and maybe port_hash
				next_hop_ip = next_hop_route_entry.next_hop.ip
				next_hop_hostname = next_hop_route_entry.next_hop.hostname

				next_hop_port = @port_hash[next_hop_hostname]

				socket = TCPSocket.open(next_hop_ip, next_hop_port)

				socket.puts(packet.to_json)

				# Close socket in use
				socket.close

				$log.debug "Succesfully sent packet with destination: 
				#{destination_hostname} to #{next_hop_hostname}
				packet: #{packet.to_json.inspect}"
			rescue Errno::ECONNREFUSED => e

				#TODO handle this. Could mean link or node is down
				#TODO test if this handles links that are down.
				$log.warn "Conection refused to #{neighbor_ip}:#{@port} will \
				append to end of forward queue and try again later retry"

				#Push to end of queue to try again later
				@forward_queue.push packet #Note this messes up the order 

				sleep 1 if $debug

				
			end
		end
	end

	# ---------------------------------------------------------------------
	# Listens for incoming connections to facilitate packet queueing.
	# Once a packet has arrived, a new thread is created to handle the client.
	# The packets is parsed and the type of packet is checked.
	# If the packet is a Link State Packet it is added to the Link State Packet
	# Queue. If the packet is a Control Message Packet then it is added to the
	# Control Message Packet Queue.
	# ---------------------------------------------------------------------
	def packet_listener
		loop {

			Thread.start(@link_state_socket.accept) do |otherNode|
				received_json = ""

				#receive the json data from the node
				#parse packet and type
				#push packets to respective queue types
				while lsp_str = otherNode.gets
					#parse packet and get packet type
					packet, packet_type = Packet.from_json(lsp_str)
					$log.debug "Received #{packet_type}: #{lsp_str}"

					if packet_type.eql? "LSP"
						@lsp_queue << packet #add packet to Link State Queue
					else
						@cmp_queue << packet #add packet to Control Message Queue
						$log.debug "appended #{packet} to cmp_queue"
					end

				end

	
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

		# creating the file and writing routing table information
		File.open(filename, "w+") { |file|
			if @routing_table != nil
				@routing_table.each { |destination, info|
					file.puts("#{@source_ip},#{info.destination.ip},#{info.next_hop.ip},#{info.distance}")
				}
			end

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
		packet_changed = @flooding_utility.has_changed(@weights_config_filepath)

		if (packet_changed)
			@routing_table_updating = true
			@routing_table = DijkstraExecutor.routing_table(@flooding_utility.global_top.graph, @source_hostname)
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

	# ----------------------------------------------------------------
	# Performs the SHUTDOWN command...
	# ----------------------------------------------------------------
	def perform_shutdown
		# shutdown all open sockets
		# print current buffer information
	end




	# -------------------------------------------------
	# Main processing method that creates the
	# threads to perform the various operations that
	# a node has to perform.
	# -------------------------------------------------
	def process
		Thread.abort_on_exception = true
		threads = [ Thread.new { update_time }, 
					Thread.new { control_message_listener }, 
					Thread.new { packet_listener },
					Thread.new { link_state_packet_processor },
					Thread.new { packet_forwarder } ]

		loop {

				inputted_command = STDIN.gets

				# if stdin contains some text then parse it
				if inputted_command != nil && inputted_command != ""
					if /#{DUMPTABLE}/.match(inputted_command)
						filename = $1 #passing in $1 directly passes nil for some reason
						Thread.new { perform_dumptable(filename) }
					elsif /#{FORCEUPDATE}/.match(inputted_command)
						Thread.new { perform_forceupdate }
					elsif /#{CHECKSTABLE}/.match(inputted_command)
						Thread.new { perform_checkstable }
					elsif /#{SHUTDOWN}/.match(inputted_command)
						Thread.new { perform_shutdown }
					elsif /#{TRACEROUTE}/.match(inputted_command)
						hostname = $1
						Thread.new { perform_traceroute(hostname) }
					end
				end
		}

	end

  # ---------------------------------------
  # Utility method used to parse out the 
  # ports that each of the nodes need to 
  # connect to
  # ---------------------------------------
  def parse_port(file)

    # Initialize port hash to store the node names 
    # and the correct ports to run off of
    port_hash = Hash.new
    
    File.open(file, "r").readlines.each do |line|
      nodes = line.split('=')

      port_hash[nodes.first] = nodes[1].chomp
    end

    $log.debug("Created port hash #{port_hash.inspect}")

    port_hash
  end 

end


# run processing function
MainProcessor.new(ARGV).process
