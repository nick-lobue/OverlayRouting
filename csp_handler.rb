require 'base64'
require 'openssl'

require_relative 'control_msg_packet.rb'

#Handles Control Message Packets (CMPs) from the CMP queue
#Functions might return packets to add to forward_queue
class ControlMessageHandler

	#TODO delete and use actual encryption
	def self.decrypt(key, plain)
		return plain
	end

	def self.handle(main_processor, control_message_packet, optional_args=Hash.new)
		$log.debug "Processing #{control_message_packet.inspect}"
		payload = control_message_packet.payload

		cmp_type = control_message_packet.type

		if cmp_type.eql? "TRACEROUTE"
			self.handle_traceroute_cmp(main_processor, control_message_packet, optional_args)
		elsif cmp_type.eql? "FTP"
			self.handle_ftp_cmp(main_processor, control_message_packet, optional_args)
		elsif cmp_type.eql? "PING"
			self.handle_ping_cmp(main_processor, control_message_packet, optional_args)
		elsif cmp_type.eql? "SND_MSG"
			self.handle_send_message_cmp(main_processor, control_message_packet, optional_args)
		elsif cmp_type.eql? "TOR"
			self.handle_tor(main_processor, control_message_packet, optional_args)
		elsif cmp_type.eql? "CLOCKSYNC"
			self.handle_clocksync_cmp(main_processor, control_message_packet, optional_args)
		else
			$log.warn "Control Message Type: #{cmp_type} not handled"
		end	
	end


	def self.handle_tor(main_processor, control_message_packet, optional_args)

		tor_payload_encrypted = Base64.decode64(control_message_packet.payload["TOR"])

		#tor_payload_encrypted = JSON.parse control_message_packet.payload["TOR"]

		#Get symmetric key and iv from uppermost layer using RSA private key
		upper_layer_key = main_processor.private_key.private_decrypt(Base64.decode64(control_message_packet.encryption['key']))
		upper_layer_iv = main_processor.private_key.private_decrypt(Base64.decode64(control_message_packet.encryption['iv']))

		decipher = OpenSSL::Cipher::AES128.new(:CBC)
		decipher.decrypt
		decipher.key = upper_layer_key
		decipher.iv = upper_layer_iv

		#decrypt with own RSA private key

		tor_payload = decipher.update(tor_payload_encrypted) + decipher.final
		tor_payload = JSON.parse tor_payload

		$log.debug "onions: \"#{tor_payload.inspect}\""

		#payload = JSON.parse payload
		if tor_payload["complete"] == true
			#Arrived at destination
			puts "Received onion message: \"#{tor_payload["message"]}\""
		else
			#Current hop is intermediate hop
			#Unwrap lower cmp and forward
			csp_str = tor_payload["next_cmp"]
			$log.debug "next_cmp: #{csp_str.inspect}"
			csp = ControlMessagePacket.from_json_hash JSON.parse csp_str
			$log.debug "TOR unwrapped and forwarding to #{csp.destination_name} #{csp.inspect}"
			return csp, {}
		end
		

	end

	#Handle a traceroute message 
	def self.handle_traceroute_cmp(main_processor, control_message_packet, optional_args)
		#A traceroute message is completed when payload["complete"] is true
		#and payload["original_source_name"] == main_processor.source_hostname
		#In that case payload["traceroute_data"] will have our data

		#TODO handle timeouts

		payload = control_message_packet.payload

		if payload["failure"]

			if control_message_packet.destination_name.eql? main_processor.source_hostname
				$log.debug "Traceroute timeout #{(main_processor.node_time.to_f ) - control_message_packet.time_sent}"
				$log.debug "Failed Traceroute arrived back #{payload.inspect}"
				puts "#{main_processor.timeout} ON #{payload["HOPCOUNT"]}"
			else
				#Else data is complete. It is just heading back to original source
				return control_message_packet, {}
			end
		elsif payload["complete"]
			if control_message_packet.destination_name.eql? main_processor.source_hostname

				$log.debug "Traceroute timeout #{(main_processor.node_time.to_f ) - control_message_packet.time_sent}"
				if main_processor.timeout <= (main_processor.node_time.to_f ) - control_message_packet.time_sent
					$log.debug "Failed Traceroute arrived back #{payload.inspect}"
					puts "#{main_processor.timeout} ON #{payload["HOPCOUNT"]}"
				else
					#TODO additional timeout check here
					$log.debug "Traceroute arrived back #{payload.inspect}"
					puts payload["data"]
				end
			else
				#Else data is complete. It is just heading back to original source
				return control_message_packet, {}
			end
			
		else

			$log.debug "Traceroute timeout #{(main_processor.node_time.to_f ) - control_message_packet.time_sent}"
			#If the timeout is less than or equal to the current time - the time the packet was sent give a failure
			if main_processor.timeout <= (main_processor.node_time.to_f ) - control_message_packet.time_sent
				$log.debug "Traceroute timeout #{(main_processor.node_time.to_f ) - control_message_packet.time_sent}"
				#Update hopcount
				payload["HOPCOUNT"] = payload["HOPCOUNT"].to_i + 1

				payload["data"] = "" # clear payload
				payload["failure"] = true

				#send back to host early
				control_message_packet = ControlMessagePacket.new(main_processor.source_hostname,
				main_processor.source_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "TRACEROUTE", payload, control_message_packet.time_sent)

				control_message_packet.payload = payload
				return control_message_packet, {}
			end

			#Get difference between last hop time and current time in milliseconds
			hop_time = (main_processor.node_time * 1000).to_i - payload["last_hop_time"].to_i
			hop_time.ceil

			#Update hop time on payload in ms
			payload["last_hop_time"] = (main_processor.node_time.to_f * 1000).ceil

			#Update hopcount
			payload["HOPCOUNT"] = payload["HOPCOUNT"].to_i + 1

			payload["data"] += "#{payload["HOPCOUNT"]} #{main_processor.source_hostname} #{hop_time}\n"



			#Trace Route has reached destination. Send a new packet to original
			#source with the same data but marked as completed
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				payload["complete"] = true
				#preserve original time sent
				control_message_packet = ControlMessagePacket.new(main_processor.source_hostname,
				main_processor.source_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "TRACEROUTE", payload, control_message_packet.time_sent)

			end

			control_message_packet.payload = payload
			return control_message_packet, {}
		
		end

	end

	#Handle a ftp message 
	def self.handle_ftp_cmp(main_processor, control_message_packet, optional_args)
		#TODO handle fragmented packets later
		#TODO handle partial data received

		payload = control_message_packet.payload

		unless control_message_packet.destination_name.eql? main_processor.source_hostname
			#packet is not for this node and we have nothing to add. Just forward it along.
			return control_message_packet, {}
		end

		if payload["failure"]
			puts "FTP: ERROR: #{payload["file_name"]} --> #{control_message_packet.source_name} INTERRUPTED AFTER #{payload["bytes_written"]}"
		elsif payload["complete"]
			#TODO handle Returned FTP complete. Packet back at source to handle
			$log.debug "TODO FTP packet arrived back #{payload.inspect}"

			#Calculate seconds since initial FTP packet
			time = main_processor.node_time.to_f - control_message_packet.time_sent
			time = time.ceil

			speed = 0
			begin
				speed = (payload["size"].to_i / time).floor
			rescue Exception => e
				throw e #TODO delete
				#probably a 0 as time just use 0 as the speed then
			end

			puts "FTP: #{payload["file_name"]} --> #{control_message_packet.source_name} in #{time} at #{speed}"
			return nil, {} # no packet to forward
		else
			begin
				file_path = payload["FPATH"] + '/' + payload["file_name"]

				file_exists = File.exists? file_path

				begin
					file = File.open(file_path, "w+b:ASCII-8BIT")
					file.print Base64.decode64(payload["data"])
				rescue Exception => e
					#if file existed before attempted write don't delete
					unless file_exists
						File.delete file_path
						$log.info "deleted #{file_path} since FTP failed"
					end
					throw e
				end

				if file
					bytes_written = file.size
				else
					bytes_written = 0
				end

				file.close

				unless bytes_written.eql? payload["size"]
					#TODO I don't think this can happen when we do fragmentation
					throw "FTP size mismatch. Payload size: #{payload["size"]} != bytes_written: #{bytes_written}"
				end

				payload["complete"] = true
				payload.delete "data" #clear data

				#Create new control message packet to send back to source but preserve original node time
				control_message_packet = ControlMessagePacket.new(control_message_packet.destination_name,
				control_message_packet.destination_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "FTP", payload, control_message_packet.time_sent)

				puts "FTP: #{control_message_packet.source_name} --> #{file_path}"

				control_message_packet.payload = payload
				return control_message_packet, {}

			rescue Exception => e

				$log.debug "FTP Exception #{e.inspect}"
				puts "FTP: ERROR: #{control_message_packet.source_name} --> #{file_path}"

				payload["complete"] = false
				payload["failure"] = true
				payload.delete "data" #clear data

				payload["bytes_written"] = 0 #TODO handle partial data

				#Create new control message packet to send back to source but preserve original node time
				control_message_packet = ControlMessagePacket.new(control_message_packet.destination_name,
				control_message_packet.destination_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "FTP", payload, control_message_packet.time_sent)

				return control_message_packet, {}
			end
		end
	end

	# ----------------------------------------------------------
	# Reconstructs the command message packet for ping
	# commands. Returns the changed packet if it still needs
	# to be forwards, otherwise it returns nil.
	# ----------------------------------------------------------
	def self.handle_ping_cmp(main_processor, control_message_packet, optional_args)
		
		# Set local variable payload to access the
		# control message packet's payload quicker 
		payload = control_message_packet.payload

		# Make sure this packet has not timed out
		# Check if we are at the correct node and if the packet has already timed
		# out. Then check the notification variable
		if main_processor.timeout_table.has_key?(payload['unique_id']) && has_timed_out(main_processor, control_message_packet.time_sent)
			# Check if there has been a notification for a timeout
			if !main_processor.timeout_table[payload['unique_id']][1]	
				main_processor.timeout_table[payload['unique_id']][1] = true
				puts "PING ERROR: HOST UNREACHABLE"
			end

			return nil
		end 

		unless control_message_packet.destination_name.eql? main_processor.source_hostname
			#packet is not for this node and we have nothing to add. Just forward it along.
			return control_message_packet, {}
		end

		# First check if the packet is complete
		if payload["complete"]

			# Then check if the packet is at its destination
			# If it is at its destination then the packet has made its
			# round trip.
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				puts "#{payload['SEQ_ID']} #{control_message_packet.source_name} #{main_processor.node_time - control_message_packet.time_sent}"
			else
				# Continue to travel to next node
				return control_message_packet, {}
			end

		# Packet is at its destination but is not complete must 
		# set complete to true and return to sender	
		elsif control_message_packet.destination_name.eql? main_processor.source_hostname
			payload["complete"] = true

			# Create new control message to send back to source.
			# We must also preserve the time sent to calculate the 
			# round trip time
			control_message_packet = ControlMessagePacket.new(control_message_packet.destination_name,
				control_message_packet.destination_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "PING", payload, control_message_packet.time_sent)

			return control_message_packet, {}

		end
	end

	# -----------------------------------------------------------
	# Reconstructs a control message packet according to the
	# current node that it is on. Returns nil if the packet has
	# gotten back to its origin, otherwise it returns the
	# changed control message packet.
	# -----------------------------------------------------------
	def self.handle_send_message_cmp(main_processor, control_message_packet, optional_args)
		payload = control_message_packet.payload

		if payload["complete"]
			# if the packet has made a round trip, determine if it was a success or
			# not and print the corresponding messages
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				if payload["failure"]
					$log.debug "SendMessage got back to the source but failed to fully send to recipient, payload: #{payload.inspect}"
					puts "SENDMSG ERROR: #{control_message_packet.source_name} UNREACHABLE"
				end
			else
				# hasn't gotten back to source yet, so return packet so that it'll be forwarded
				return control_message_packet, {}
			end
		else
			# arrived at the destination, send back to source node so that the source can 
			# confirm if the message was fully received by inspecting the presence of
			# the failure key in the payload hash
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				if payload["size"].to_i != payload["message"].size
					payload["failure"] = true
				else
					$log.debug "SendMessage got to the destination successfully, payload: #{payload.inspect}"
					puts("SENDMSG: #{control_message_packet.source_name} --> " + payload["message"])
				end

				payload["complete"] = true
				control_message_packet = ControlMessagePacket.new(main_processor.source_hostname,
				main_processor.source_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "SND_MSG", payload, main_processor.node_time)
			end

			control_message_packet.payload = payload
			return control_message_packet, {}
		end
	end

	# -----------------------------------------------------------
	# Reconstructs a control message packet according to the
	# current node that it is on. Returns nil if the packet has
	# gotten back to its origin, otherwise it returns the
	# changed control message packet. Saves node time in
	# payload and sends back to source if at destination.
	# -----------------------------------------------------------
	def self.handle_clocksync_cmp(main_processor, control_message_packet, optional_args)
		payload = control_message_packet.payload

		if payload["destination_time"]
			# determine if packet has made a round trip
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				$log.debug "CLOCKSYNC has made a full round trip."
				round_trip_time = (Time.at(main_processor.node_time) - Time.at(control_message_packet.time_sent)) / 2

				# determine if this node's time needs to be synced 
				needs_syncing = Time.at(main_processor.node_time) <=> Time.at(payload["destination_time"] + round_trip_time)
				if needs_syncing == -1
					delta = (payload["destination_time"] + round_trip_time - main_processor.node_time)
					main_processor.node_time = payload["destination_time"] + round_trip_time

					$log.debug "Node's (#{main_processor.source_hostname}) time is behind node (#{control_message_packet.source_name}) and is being synced."
					puts Time.at(main_processor.node_time).strftime("CLOCKSYNC: TIME = %H:%M:%S DELTA = #{delta}")
				else
					$log.debug "Node's (#{main_processor.source_hostname}) time is ahead of node (#{control_message_packet.source_name}) and should NOT be synced."
				end

				return nil, {}  # return nil because packet has made a round trip
			else
				# hasn't gotten back to source yet, so return packet so that it'll be forwarded
				return control_message_packet, {}
			end
		else
			# arrived at the destination, send back to source node so that the source can 
			# sync its node time if need be
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				$log.debug "CLOCKSYNC got to the destination (#{main_processor.source_hostname} successfully.)"
				puts Time.at(main_processor.node_time).strftime("CLOCKSYNC FROM #{control_message_packet.source_name}: TIME = %H:%M:%S")

				payload["destination_time"] = main_processor.node_time
				control_message_packet = ControlMessagePacket.new(main_processor.source_hostname,
				main_processor.source_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "CLOCKSYNC", payload, control_message_packet.time_sent)
			end

			control_message_packet.payload = payload
			return control_message_packet, {}
		end
	end

	# ----------------------------------------------------------
	# Helper method used to determine if a packet has timed
	# out or not. Does this by comparing the node's time
	# with the packet's origin time.
	# ----------------------------------------------------------
	def has_timed_out(main_processor, packet_time)
		return main_processor.node_time - packet_time > main_processor.ping_timeout 
	end

end