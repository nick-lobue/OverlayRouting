require_relative 'control_msg_packet.rb'

#Handles Control Message Packets
class ControlMessageHandler


	def self.handle(main_processor, control_message_packet, optional_args=Hash.new)
		$log.debug "Processing #{control_message_packet.inspect}"
		payload = control_message_packet.payload

		cmp_type = control_message_packet.type

		if cmp_type.eql? "TRACEROUTE"
			self.handle_traceroute_cmp(main_processor, control_message_packet, optional_args)
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
			if payload["original_source_name"].eql? main_processor.source_hostname
				#TODO Finally at source handle correctly
				$log.debug "Traceroute arrived back #{payload.inspect}"
				puts payload["data"]
			else
				#Else data is complete. It is just heading back to original source
				return control_message_packet, {}
			end
			
		else
			#Get difference between last hop time and current time
			hop_time = main_processor.node_time - payload["last_hop_time"].to_f

			#Update hop time on payload
			payload["last_hop_time"] = main_processor.node_time

			#Update hopcount
			payload["HOPCOUNT"] = payload["HOPCOUNT"].to_i + 1

			payload["data"] += "#{payload["HOPCOUNT"]} #{main_processor.source_hostname} #{payload["last_hop_time"]}\n"

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
end