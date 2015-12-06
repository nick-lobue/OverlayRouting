require 'json'
require_relative 'packet.rb'

#TODO discuss what fields to use in Control Message
#TODO How will we fragmentation

class ControlMessagePacket < Packet
	attr_accessor :source_name, :source_ip, :destination_name, :destination_ip, :seq_numb, :payload, :type, :time_sent, :encryption, :frag_id, :payloadInfo

	# ---------------------------------------
	# Initialize the fields of the Control Message
	# packet
	# TODO do we need the ip? Or we could make it optional
	# ---------------------------------------
	def initialize(source_name, source_ip, destination_name, destination_ip, seq_numb, type, payload, time_sent, encryption=nil, frag_id=nil, payloadInfo=Hash.new)

		if source_name.nil? or seq_numb.nil? or (encryption.nil? and type.eql? "TOR")
			throw :invalid_argument
		end

		@destination_name = destination_name
		@destination_ip = destination_ip
		@source_name = source_name
		@source_ip = source_ip
		@seq_numb = seq_numb
		@payload = payload
		@type = type
		@time_sent = time_sent
		@encryption = encryption

		#If 0 or nil then don't fragment
		@frag_id = frag_id
		@byteCount = 0
		@payloadInfo = payloadInfo
	end

	# -------------------------------------
	# Override the to json method to set up 
	# object for parsing
	# -------------------------------------
	def to_json_from_cmp
		#TODO add rest of required fields
		{ 'packet_type' => "CMP", 'source_name' => @source_name, 'source_ip' => @source_ip, 'seq_numb' => 
			@seq_numb, 'type'=> @type, 'payload' => @payload, 'destination_name' => @destination_name,
			"destination_ip" => @destination_ip, "time_sent" => time_sent.to_f, 'encryption' => @encryption, "frag_id" => @frag_id}.to_json
	end

	#Takes a json hash and fully constructs it into a ControlMessagePacket
	def self.from_json_hash(data)
		#TODO add rest of required fields
		ControlMessagePacket.new(
			data['source_name'], data['source_ip'],
			data['destination_name'], data['destination_ip'],
			data['seq_numb'].to_i, data['type'], data['payload'],
			data['time_sent'].to_f, data['encryption'], data['frag_id'].to_i)

	end

end
