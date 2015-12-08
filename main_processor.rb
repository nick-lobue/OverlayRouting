require 'time'
require 'socket'
require 'thread'
require 'openssl'
require 'securerandom'

require_relative 'packet.rb'
require_relative 'link_state_packet.rb'
require_relative 'control_msg_packet.rb'
require_relative 'graph_builder.rb'
require_relative 'flooding_utility.rb'
require_relative 'dijkstra_executor.rb'
require_relative 'performer.rb'
require_relative 'csp_handler.rb'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG
$debug = true #TODO set to false on submission

# --------------------------------------------
# Holds the operations needed to combine
# all aspects of the program.
# --------------------------------------------
class MainProcessor

	attr_accessor :source_hostname, :source_ip, :source_port, :node_time, :routing_table, 
		:flooding_utility, :weights_config_filepath, :nodes_config_filepath, :routing_table_updating,
		:keys, :private_key, :public_key, :graph_mutex, :timeout

	# regex constants for user commands
	DUMPTABLE = "^DUMPTABLE\s+(.+)$"
	FORCEUPDATE = "^\s*FORCEUPDATE\s*$"
	CHECKSTABLE = "^\s*CHECKSTABLE\s*$"
	SHUTDOWN = "^\s*SHUTDOWN\s*$"

	TRACEROUTE = "^TRACEROUTE\s+(.+)$"
	FTP = "^FTP\s+(.+)\s+(.+)\s+(.+)$"
	PING = "^PING\s+(.+)\s+([0-9]+)\s+([0-9 | \.]+)$"
	SEND_MESSAGE = "^SNDMSG\s+([0-9a-zA-Z\w]+)\s+(.+)$"
	CLOCKSYNC = "^\s*CLOCKSYNC\s*$"
	TOR = "^TOR\s+(.+)\s+(.+)$"


	# ------------------------------------------------------
	# Parses through the configuration file to
	# obtain the update interval and the file
	# paths for the other configuration files.
	# @param config_filepath File path for config file.
	# ------------------------------------------------------
	def parse_config_file(config_filepath)
		File.open(config_filepath).each do |line|
			if line =~ /\s*updateInterval\s*=\s*(\d+)\s*/
				@update_interval = $1.to_f
			elsif line =~ /\s*weightFile\s*=\s*(.+)\s*/
				@weights_config_filepath = $1
			elsif line =~ /\s*nodes\s*=\s*(.+)\s*/
				@nodes_config_filepath = $1
			elsif line =~ /\s*maxPacketSize\s*=\s*(.+)\s*/
				@max_packet_size = $1
			elsif line =~ /\s*pingTimeout\s*=\s*(.+)\s*/
				@ping_timeout = $1
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

		@timeout_table = Hash.new
		@node_time = Time.now.to_f
		@config_filepath = arguments[0]
		@source_hostname = arguments[1]

		$log.debug("config_filepath: #{@config_filepath} source_hostname: #{@source_hostname}")

		# parse files to get network information
		parse_config_file(@config_filepath)
		@timeout = 1 #TODO read from config file
		extract_ip_and_port(@weights_config_filepath, @nodes_config_filepath, @source_hostname)

		#generate public and private keys
		@private_key = OpenSSL::PKey::RSA.new(2048)
		@public_key = @private_key.public_key

		#TODO get keys from lsp
		@keys = Hash.new

		#A queue containing link state packets
		@lsp_queue = Queue.new

		#A queue containing control message packets
		@cmp_queue = Queue.new

		#A hash to forward queues from hostnames
		@forward_queue = Queue.new

		@port_hash = parse_port @nodes_config_filepath

		@routing_table_mutex = Mutex.new
		@graph_mutex = Mutex.new

		#Create initial blank routing table
		@routing_table = RoutingTable.blank_routing_table(@source_hostname, @source_ip)

		@flooding_utility = FloodingUtil.new(@source_hostname, @source_ip, @port_hash, @weights_config_filepath, @public_key)

		@routing_table_updating = false
		@packet_socket = TCPServer.open(@source_port)

		@graph_mutex.synchronize {
			#flood initial link state packet
			@flooding_utility.initial_flood
		}

		
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
			#@node_time = Time.now.to_f 
			sleep(0.001)
		}
	end

	# -------------------------------------------------
	# Constantly updates the timeout table used at each
	# node. Will delete the specific packet entry and 
	# print a timeout message if the message has 
	# outlived its lifespan
	# -------------------------------------------------
	def update_timeout_table
		loop {
			@timeout_table.each do |(key, type), (n_time, notified)|

				# Check first if the id in the table has outlived its lifespan
				if @node_time - n_time > @ping_timeout

					# Check if the id in the table is more than 5 mins old.
					# This is done to allow for a lag in clean up 
					if @node_time - n_time > 5000
						@timeout_table.delete([key, type])
					else
						if type == 'PING' && !notified
							notified = true
							puts "PING ERROR: HOST UNREACHABLE"
						else 
						# if type == traceroute
						end
					end
				end
			end

			sleep(1)
		}
	end


	# ---------------------------------------------------------------------
	# Listens for incoming connections in order to handle control
	# message transmissions. Once a control message has arrived, it's
	# task is executed in a separate thread so that the node may still
	# be listening for other messages coming through.
	# ---------------------------------------------------------------------
	def control_message_listener

		#pop and process all available control message packets
		#will block until packets pushed to queue
		while control_message_packet = @cmp_queue.pop

			#Note to Nick and Tyler: If you need to add more arguments just pass them in
			#the optional_args hash. Then retrive it from the hash.
			#Example self.handle(main_processor, control_message_packet, {'time'=>'time', 'timeout'=>15}
			#Similar concept with getting return values. optional return is also a hash.
			packets_to_forward, optional_return = ControlMessageHandler.handle(self, control_message_packet, {})

			unless packets_to_forward.nil?
				@forward_queue << packets_to_forward
			end

		end
	end

	#Pops  packets and calls check_link_state_packet on each of them
	#After checking all of them it updates the routing table
	#Then it waits until more data is added in the queue
	def link_state_packet_processor
		while link_state_packet = @lsp_queue.pop
			$log.debug "Processing #{link_state_packet.inspect}"

			@graph_mutex.synchronize {
				# flood the received packet, update topology graph, and update routing table
				@flooding_utility.check_link_state_packet(link_state_packet)

				@keys[link_state_packet.source_name] = OpenSSL::PKey::RSA.new link_state_packet.public_key
				$log.debug "Added public key #{link_state_packet.source_name} => #{@keys[link_state_packet.source_name]}"

				#Optimization: Process additional link state packets but without blocking
				until @lsp_queue.empty?
					link_state_packet = @lsp_queue.pop
					@flooding_utility.check_link_state_packet(link_state_packet)
					@keys[link_state_packet.source_name] = OpenSSL::PKey::RSA.new link_state_packet.public_key
					$log.debug "Added public key #{link_state_packet.source_name} => #{@keys[link_state_packet.source_name]}"
				end

				@routing_table_updating = true

				#$log.debug "Global topology: #{@flooding_utility.global_top.graph.inspect}"
				updated_routing_table = DijkstraExecutor.routing_table(@flooding_utility.global_top, @source_hostname)

				@routing_table_mutex.synchronize {
					@routing_table = updated_routing_table
				}

				$log.info "Routing table updated"
				@routing_table.print_routing if $debug

				@routing_table_updating = false
			}
		end
	end

	#TODO handle link state packets
	#Listens to forward_queue and forwards any new packets to next hop
	#This is outgoing not incoming. Incoming queues are cmp_queue and lsp_queue
	def packet_forwarder
		while packet = @forward_queue.pop

			destination_hostname = packet.destination_name

			begin

				#TODO should I wait until the routing table is stable to forward packet?
				next_hop_route_entry = nil
				@routing_table_mutex.synchronize {
					#Forward to next hop
					next_hop_route_entry = @routing_table[destination_hostname]
				}

				#If hop does not exist forward back to original node
				if next_hop_route_entry.nil?

                    @routing_table_mutex.synchronize {
						next_hop_route_entry = @routing_table[packet.source_name]
                	}

					if next_hop_route_entry.nil? and packet.retries < 6
						#Weird case source and destination can not be found
						#from the routing table
						#Sleep for a second and requeue packet
						#Hopefully the routing table might display at least on them
						#Give 5 attempts before giving up
						Thread.new {
							$log.error "No next route for #{packet.source_name} or
							#{packet.destination_hostname} for packet: #{packet.inspect}"
							sleep 1
							packet.failures = packet.failures + 1
							@forward_queue << packet
						}
					elsif next_hop_route_entry.nil?
	
					else
						#TODO send back to parent maybe talk to Nick and Tyler about this
						#We could continue retrying
						#TODO maybe
						Thread.new {
							$log.error "No next route for #{packet.source_name} or
							#{packet.destination_hostname} for packet: #{packet.inspect}"
							sleep 1
							packet.failures = packet.failures + 1
							@forward_queue << packet
						}
					end
				end

				#TODO create mutex for routing table and maybe port_hash
				next_hop_ip = next_hop_route_entry.next_hop.ip
				next_hop_hostname = next_hop_route_entry.next_hop.hostname

				next_hop_port = @port_hash[next_hop_hostname]

				socket = TCPSocket.open(next_hop_ip, next_hop_port)


				socket.puts(packet.to_json_from_cmp)

				# Close socket in use
				socket.close

				$log.debug "Succesfully sent packet with destination: 
				#{destination_hostname} to #{next_hop_hostname}
				packet: #{packet.to_json_from_cmp.inspect}"
			rescue Errno::ECONNREFUSED => e

				#TODO handle this. Could mean link or node is down
				#TODO test if this handles links that are down.
				next_hop_route_entry = nil
				@routing_table_mutex.synchronize {
					next_hop_route_entry = @routing_table[packet.destination_name]
				}

				$log.warn "Connection refused to #{next_hop_route_entry}:#{@port_hash[next_hop_route_entry.next_hop.hostname]} will \
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

			Thread.start(@packet_socket.accept) do |otherNode|
				received_json = ""

				#receive the json data from the node
				#parse packet and type
				#push packets to respective queue types
				while packet_str = otherNode.gets
					#parse packet and get packet type
					packet, packet_type = Packet.from_json(packet_str)
					$log.debug "Received #{packet_type}: #{packet_str}"

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

	# ----------------------------------------------------
	# Sleeps for however long the update interval
	# specifies, then updates the routing table by
	# calling forceupdate method. This function will be
	# called in its own thread.
	# ----------------------------------------------------
	def recurring_routing_table_update
		loop {
			sleep(@update_interval)
            @routing_table_mutex.synchronize {
            	$log.debug "Attempting to perform a recurring routing table update."
				Performer.perform_forceupdate(self)
            }
		}
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
					Thread.new { packet_forwarder },
					Thread.new { recurring_routing_table_update } ]

		loop {

			inputted_command = STDIN.gets

				# if stdin contains some text then parse it
				if inputted_command != nil && inputted_command != ""
					if /#{DUMPTABLE}/.match(inputted_command)
						filename = $1 #passing in $1 directly passes nil for some reason
						Thread.new { Performer.perform_dumptable(self, filename) }
					elsif /#{FORCEUPDATE}/.match(inputted_command)
						Thread.new { Performer.perform_forceupdate(self) }
					elsif /#{CHECKSTABLE}/.match(inputted_command)
						Thread.new { Performer.perform_checkstable(self) }
					elsif /#{SHUTDOWN}/.match(inputted_command)
						Thread.new { Performer.perform_shutdown(self) }
					elsif /#{TRACEROUTE}/.match(inputted_command)
						hostname = $1
						Thread.new {
							packet = Performer.perform_traceroute(self, hostname)
							if packet.class.to_s.eql? "ControlMessagePacket"
								@forward_queue << packet
							else
								$log.debug "Nothing to forward #{packet.class}"
							end
						}
					elsif /#{FTP}/.match(inputted_command)
						hostname = $1
						file_name = $2
						epath = $3
						Thread.new {
							packet = Performer.perform_ftp(self, hostname, file_name, epath)
							if packet.class.to_s.eql? "ControlMessagePacket"
								@forward_queue << packet
							else
								$log.debug "Nothing to forward #{packet.class}"
							end
						}
					elsif /#{PING}/.match(inputted_command)
						dest_hostname = $1
						num_pings = $2.to_i
						delay = $3.to_f
						Thread.new {
							# Create the number of pings amount of pings
							for i in 0..num_pings-1

								# Unique id for this packet to store in the
								# timeout table. A boolean is appended to
								# keep track if a notification was written to 
								# standard out or not
								unique_id = SecureRandom.hex(8)
								@timeout_table[['#{unique_id}', 'PING']] = [@node_time, false]

								# Create packet
								packet = Performer.perform_ping(self, dest_hostname, i, unique_id)

								# Wait the time of the delay to send out the next ping
								sleep(delay)
							end
						}
					elsif /#{SEND_MESSAGE}/.match(inputted_command)
						destination = $1
						message = $2

						Thread.new {
							packet = Performer.perform_send_message(self, destination, message)
							if packet.class.to_s.eql? "ControlMessagePacket"
								@forward_queue << packet
							else
								$log.debug "Nothing to forward #{packet.class}"
							end
						}
					elsif /#{CLOCKSYNC}/.match(inputted_command)
						Thread.new {
							@flooding_utility.link_state_packet.neighbors.keys.each do |(neighbor_name, neighbor_ip)|
								packet = Performer.perform_clocksync(self, neighbor_name)

								if packet.class.to_s.eql? "ControlMessagePacket"
									@forward_queue << packet
								else
									$log.debug "Nothing to forward #{packet.class}"
								end
							end
						}
					elsif /#{TOR}/.match(inputted_command)
						destination = $1
						message = $2

						Thread.new {
							packet = Performer.perform_tor(self, destination, message)
							if packet.class.to_s.eql? "ControlMessagePacket"
								@forward_queue << packet
							else
								$log.debug "Nothing to forward #{packet.class}"
							end
						}
					elsif /PRINT_TIME/.match(inputted_command)
						Thread.new {
							puts("Current Node Time:  #{Time.at(@node_time)}")
						}

					else
						$log.debug "Did not match anything. Input: #{inputted_command}"
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
