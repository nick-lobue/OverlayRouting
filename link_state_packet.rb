require 'json'

class LinkStatePacket
	attr_accessor :source_name, :source_ip, :seq_numb, :neighbors

	# ---------------------------------------
	# Initialize the fields of the link state
	# packet and create a new hash to store 
	# the neighbors of the node
	# ---------------------------------------
	def initialize(source_name, source_ip, seq_numb)
		@source_name = source_name
		@source_ip = source_ip
		@seq_numb = seq_numb
		@neighbors = Hash.new
	end

	# --------------------------------------
	# Initilize all fields of link state
	# packet including a hash of neighbors
	# --------------------------------------
	def initialize(source_name, source_ip, seq_numb, neighbors)
		@source_name = source_name
		@source_ip = source_ip
		@seq_numb = seq_numb
		@neighbors = neighbors
	end

	# -------------------------------------
	# Override the to json method to set up 
	# object for parsing
	# -------------------------------------
	def to_json
		{'source_name' => @source_name, 'source_ip' => @source_ip, 'seq_numb' => 
			@seq_numb, 'neighbors' => @neighbors}.to_json
	end

	# -------------------------------------
	# A static method that will be used to 
	# convert a link state packet json back
	# into a link state object
	# -------------------------------------
	def self.from_json(input)
		data = JSON.parse(input)
		return LinkStatePacket.new(data['source_name'], data['source_ip'], 
			data['seq_numb'].to_i, data['neighbors'])
	end
end