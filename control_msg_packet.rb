require 'json'
require_relative 'packet.rb'

#TODO discuss what fields to use in Control Message
#TODO How will we fragmentation

class ControlMessagePacket < Packet
	attr_accessor :source_name, :source_ip,:destination_name, :destination_ip, :seq_numb, :payload

	# ---------------------------------------
	# Initialize the fields of the Control Message
	# packet
	# TODO do we need the ip? Or we could make it optional
	# ---------------------------------------
	def initialize(source_name, source_ip, destination_name, destination_ip, seq_numb, type, payload)

		if source_name.nil? or source_ip.nil? or seq_numb.nil? or payload.nil?
			throw :invalid_argument
		end

		@destination_name = destination_name
		@destination_ip = destination_ip
		@source_name = source_name
		@source_ip = source_ip
		@seq_numb = seq_numb
		@payload = payload
		@type = type

	end

	# -------------------------------------
	# Override the to json method to set up 
	# object for parsing
	# -------------------------------------
	def to_json
		#TODO add rest of required fields
		{ 'packet_type' => "CMP", 'source_name' => @source_name, 'source_ip' => @source_ip, 'seq_numb' => 
			@seq_numb, 'type'=> @type 'payload' => @payload}.to_json
	end

	#Takes a json hash and fully constructs it into a ControlMessagePacket
	def self.from_json_hash(data)
		#TODO add rest of required fields
		ControlMessagePacket.new(data['source_name'], data['source_ip'], 
			data['seq_numb'].to_i, data['payload'])

	end

end
