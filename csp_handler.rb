require 'base64'

require_relative 'control_msg_packet.rb'

#Handles Control Message Packets (CMPs) from the CMP queue
#Functions might return packets to add to forward_queue
class ControlMessageHandler


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
		else
			$log.warn "Control Message Type: #{cmp_type} not handled"
		end
			
	end

	#Handle a traceroute message 
	def self.handle_traceroute_cmp(main_processor, control_message_packet, optional_args)
		#A traceroute message is completed when payload["complete"] is true
		#and payload["original_source_name"] == main_processor.source_hostname
		#In that case payload["traceroute_data"] will have our data

		#TODO handle timeouts

		payload = control_message_packet.payload

		if payload["complete"]
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				$log.debug "Traceroute arrived back #{payload.inspect}"
				puts payload["data"]
			else
				#Else data is complete. It is just heading back to original source
				return control_message_packet, {}
			end
			
		else
			#Get difference between last hop time and current time in milliseconds
			hop_time = (main_processor.node_time * 1000).to_i - payload["last_hop_time"].to_i
			hop_time.ceil

			#Update hop time on payload
			payload["last_hop_time"] = (main_processor.node_time.to_f * 1000).ceil

			#Update hopcount
			payload["HOPCOUNT"] = payload["HOPCOUNT"].to_i + 1

			payload["data"] += "#{payload["HOPCOUNT"]} #{main_processor.source_hostname} #{hop_time}\n"

			#Trace Route has reached destination. Send a new packet to original
			#source with the same data but marked as completed
			if control_message_packet.destination_name.eql? main_processor.source_hostname
				payload["complete"] = true
				control_message_packet = ControlMessagePacket.new(main_processor.source_hostname,
				main_processor.source_ip, control_message_packet.source_name,
				control_message_packet.source_ip, 0, "TRACEROUTE", payload, main_processor.node_time)

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

	# ----------------------------------------------------------
	# Helper method used to determine if a packet has timed
	# out or not. Does this by comparing the node's time
	# with the packet's origin time.
	# ----------------------------------------------------------
	def has_timed_out(main_processor, packet_time)
		return main_processor.node_time - packet_time > main_processor.ping_timeout 
	end
end