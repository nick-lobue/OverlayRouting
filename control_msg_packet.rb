require 'json'
require_relative 'packet.rb'

#TODO discuss what fields to use in Control Message
#TODO How will we fragmentation

class ControlMessagePacket < Packet
	attr_accessor :source_name, :source_ip, :destination_name, :destination_ip, :seq_numb, :payload, :type,
	:time_sent, :encryption, :frag_id, :fragInfo, :retries

	# ---------------------------------------
	# Initialize the fields of the Control Message
	# packet
	# TODO do we need the ip? Or we could make it optional
	# ---------------------------------------
	def initialize(source_name, source_ip, destination_name, destination_ip, seq_numb, type, payload, time_sent, encryption=nil, fragInfo=Hash.new)

		if source_name.nil? or (encryption.nil? and type.eql? "TOR")
			throw :invalid_argument
		end

		@destination_name = destination_name
		@destination_ip = destination_ip
		@source_name = source_name
		@source_ip = source_ip

		if seq_numb.nil? or seq_numb.eql? 0
			@seq_numb = rand(2400000) + 1
		else
			@seq_numb = seq_numb
		end

		@payload = payload
		@type = type
		@time_sent = time_sent
		@encryption = encryption

		@fragInfo = fragInfo
		@retries = 0
	end

	# -------------------------------------
	# Override the to json method to set up 
	# object for parsing
	# -------------------------------------
	def to_json_from_cmp
		
		{ 'packet_type' => "CMP", 'source_name' => @source_name, 'source_ip' => @source_ip, 'seq_numb' => 
			@seq_numb, 'type'=> @type, 'payload' => @payload, 'destination_name' => @destination_name,
			"destination_ip" => @destination_ip, "time_sent" => time_sent.to_f, 'encryption' => @encryption, "fragInfo" => @fragInfo}.to_json
	end

	#Takes a json hash and fully constructs it into a ControlMessagePacket
	def self.from_json_hash(data)
		#TODO add rest of required fields
		ControlMessagePacket.new(
			data['source_name'], data['source_ip'],
			data['destination_name'], data['destination_ip'],
			data['seq_numb'].to_i, data['type'], data['payload'],
			data['time_sent'].to_f, data['encryption'], data['fragInfo'])

	end

end
