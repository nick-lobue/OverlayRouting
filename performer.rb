class Performer


	#returns packets to forward
	def self.perform_traceroute(main_processor, destination_name)

		if destination_name.nil?
			throw :invalid_argument
		end

		#TODO handle timeout 

		payload = Hash.new

		#Fill in initial trace route hopcount of 0 the hostname and time to get to node is 0
		payload['data'] = "0 #{@source_hostname} 0\n"

		payload["original_source_name"] = main_processor.source_hostname
		payload["original_source_ip"] = main_processor.source_ip

		control_message_packet = ControlMessagePacket.new(main_processor.source_hostname,
				main_processor.source_ip, destination_name, nil, 0, "TRACEROUTE", payload,
				main_processor.node_time)

		control_message_packet 
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
end