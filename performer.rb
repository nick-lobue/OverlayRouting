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

		@forward_queue 
	end
end