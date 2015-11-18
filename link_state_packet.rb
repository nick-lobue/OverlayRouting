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
end