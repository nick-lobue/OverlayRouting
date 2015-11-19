class LinkStatePacket
	attr_accessor :sourceName, :sourceIP, :seqNumb, :neighbors

	# ---------------------------------------
	# Initialize the fields of the link state
	# packet and create a new hash to store 
	# the neighbors of the node
	# ---------------------------------------
	def initialize(source_name, source_ip, seq_numb)
		@sourceName = source_name
		@sourceIP = source_ip
		@seqNumb = seqNumb
		@neighbors = Hash.new
	end

	# --------------------------------------
	# Initilize all fields of link state
	# packet including a hash of neighbors
	# --------------------------------------
	def initialize(source_name, source_ip, seq_numb, neighbors)
		@sourceName = source_name
		@sourceIP = source_ip
		@seqNumb = seqNumb
		@neighbors = neighbors
	end

	# --------------------------------------
	# Override toString function to make for 
	# easy parsing of objects
	# --------------------------------------
	def to_string
		return "#{@source_name},#{@source_ip},#{@seqNumb.to_s},#{@neighbors.inspect}"
	end

	# --------------------------------------
	# A static method that will be used to 
	# convert a link state packet string 
	# back into a link state object
	# --------------------------------------
	def self.from_string(input)
		link_fields = input.split(',')
		return LinkStatePacket.new(link_fields[0], link_fields[1], link_fields[2].to_i, eval(link_fields[3]))
	end
end