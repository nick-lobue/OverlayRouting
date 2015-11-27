require 'json'

class Packet
	attr_accessor :source_name, :source_ip

	# -------------------------------------
	# A static method that will be used to 
	# convert a packet's json back
	# into a link state object or control message object
	# -------------------------------------
	def self.from_json(input)

		data = JSON.parse(input)

		#determine packet type
		packet_type = data['packet_type']

		if packet_type.eql? "LSP"
			packet = LinkStatePacket.from_json_hash(data)
		else

		end

		return packet, packet_type

	end
end
