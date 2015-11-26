require 'json'

class LinkStatePacket
	attr_accessor :source_name, :source_ip, :seq_numb, :neighbors

	# ---------------------------------------
	# Initialize the fields of the link state
	# packet and create a new hash to store 
	# the neighbors of the node
	# ---------------------------------------
	def initialize(source_name, source_ip, seq_numb, neighbors)

		if source_name.nil? or source_ip.nil? or seq_numb.nil?
			throw :invalid_argument
		end

		if neighbors.class.name != "Hash" and not neighbors.nil?
			$log.debug "neighbors type: #{neighbors.class}"
			throw :invalid_argument_wrong_type
		end

		@source_name = source_name
		@source_ip = source_ip
		@seq_numb = seq_numb

		# If the neighbors parameter is nil then 
		# initialize the link state packet to have
		# an empty hash
		if neighbors.nil?
			@neighbors = Hash.new
		else
			@neighbors = neighbors
		end
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

		lsp = LinkStatePacket.new(data['source_name'], data['source_ip'], 
			data['seq_numb'].to_i, data['neighbors'])

		#keys are arrays and need to be parsed separetly
		unless data['neighbors'].nil?
			parsed_neighbors = Hash.new
			data['neighbors'].each_pair { |key, pair|
				parsed_neighbors[JSON.parse(key)] = pair
			}
			lsp.neighbors = parsed_neighbors
		end

		lsp

	end
end
