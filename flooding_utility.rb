require 'socket'
require_relative 'link_state_packet.rb'
require_relative 'graph_builder.rb'

#Needed for catching Errno exception
include Socket::Constants

class FloodingUtil
  
  attr_accessor :source_name, :source_ip, :link_state_packet, :link_state_table, :global_top, :port_hash

  # ------------------------------------------------
  # Initialize the flooding util with the info
  # needed for the link state packet
  # ------------------------------------------------
  #TODO source will usually have several ip addresses for each link
  #Maybe make source_ip a hash where every hostname maps to an outgoing link
  #example for 
  #n1 (outgoing ip: 10.0.0.20) -> n2
  #n1 (outgoing ip: 10.0.2.20) -> n3
  #source_ip will be {"n2" => 10.0.0.20 , "n3" => 10.0.2.20}
  def initialize(source_name, source_ip, port_file, config_file)
    
    $log.info "init"
    # Set source name field which marks
    # instance of node the flooding util 
    # is running on
    @source_name = source_name
    @source_ip = source_ip

    # Parse the port file
    parse_port(port_file)
    

    # Initialize link state table and insert
    # current source name and sequence number
    @link_state_table = Hash.new
    @link_state_table[@source_name] = 0

    # Construct initial graph 
    @global_top = GraphBuilder.new
    @init_node = GraphBuilder::GraphNode.new(@source_name, @source_ip)
    @global_top.add_node(@init_node)

    # Parse config file and set fields for
    # link state instance
    @link_state_packet = LinkStatePacket.new(@source_name, @source_ip, 0, nil)
    parse_config(config_file)

    # Add new neighbors to the global 
    # topology graph
    @link_state_packet.neighbors.keys.each do |(host, ip)|
    	neighbor = GraphBuilder::GraphNode.new(host, ip)
    	cost = @link_state_packet.neighbors[[host, ip]]
    	@global_top.add_node(neighbor)
    	@global_top.add_edge(@init_node, neighbor, cost)
    end

    #TODO should we worry about neighbors changing? 
    #I'm guessing not since they are defined in config file.
    @neighbors = @link_state_packet.neighbors

    $log.info("Initial FloodUtil LSP: #{@link_state_packet.inspect}")

  end

  # Flood network with initial link state packet
  def initial_flood
    flood_neighbors(@link_state_packet)
  end

  # ------------------------------------------------
  # This utility method will be used to send the
  # current link state packet to its neighbors 
  # ------------------------------------------------
  def flood_neighbors(ls_packet)

    # Use tcp sockets to send out the link
    # state packet to all of its neighbors
    @neighbors.keys.each do |(neighbor_name, neighbor_ip)|
      
      # Send packet 
      $log.debug "sending lsp to #{neighbor_ip}:#{@port}. lsp json: #{ls_packet.to_json.inspect}"
    
      sock_failure_count = 0

      begin
        socket = TCPSocket.open(neighbor_ip, @port_hash[neighbor_name])
        socket.puts(ls_packet.to_json)
        # Close socket in use
        socket.close
      rescue Errno::ECONNREFUSED => e
        
        sock_failure_count = sock_failure_count + 1

        #retry if debuging
        if $debug and sock_failure_count < 60
           #give up to 1 minute to connect if not link or host is down
          sleep 1 #TODO remove
          $log.warn "Conection refused to #{neighbor_ip}:#{@port_hash[neighbor_name]}"
          retry
        end

        #TODO handle this. Could mean link or node is down
        #TODO test if this handles links that are down.
        $log.warn "Conection refused to #{neighbor_ip}:#{@port} will not retry"
      end


    end
  end

  # -----------------------------------------------
  # This utility method will be used to check
  # the given link state packet for validity
  # and will choose wether or not to discard the
  # given packet
  # -----------------------------------------------
  def check_link_state_packet(ls_packet)

    # Check first if the given link state
    # packets source node is in the table
    if @link_state_table[ls_packet.source_name] == nil
      @link_state_table[ls_packet.source_name] = ls_packet.seq_numb
      # Build graph
      ls_packet.neighbors.keys.each do |(host, ip)| 
        neighbor = GraphBuilder::GraphNode.new(@host, @ip)
        cost = ls_packet.neighbors[[host, ip]]
        @global_top.add_node(neighbor)
        @global_top.add_edge(@init_node, neighbor, cost)
      end

    # Flood network with packe
    flood_neighbors(ls_packet) 

    # If link state is already in the table check its seq numb
    # against the recieved link state packet if it did change 
    # we want to update the table and flood
    elsif @link_state_table[ls_packet.source_name] < ls_packet.seq_numb 
      # Update lsp and topology ls table and flood
      # Update link state table
      @link_state_table[ls_packet.source_name] = ls_packet.seq_numb

      #Update global topology graph 
	    @global_top.replace_sub_topology(ls_packet.source_name, ls_packet.source_ip, ls_packet.neighbors)
      
      # Flood network with packe
      flood_neighbors(ls_packet)

    # If the recieved link state packet is in the table and
    # has the previously recorded sequence number we want
    # to drop the packet
    else        
       # Do nothing aka drop the packet
    end
  end

  # ---------------------------------------------
  # This utility method will parse out the
  # the information needed to create the link
  # state packets
  # ---------------------------------------------
  def parse_config(config_file)

    
    File.open(config_file, "r").readlines.each do |line|

      $log.info("config line #{line}")

      nodes = line.split(',')

      # Check if the first node is listed in the line
      # is the current node being run on
      if nodes.first == @source_name
        # Check and see if neighbor is already in the hash
        if @link_state_packet.neighbors.has_key?([nodes[2], nodes[3]]) == false
          @link_state_packet.neighbors[[nodes[2], nodes[3]]] = nodes[4]
        end 
       
      # Check if the third node listed in line is the
      # node being run on
      elsif nodes[2] == @source_name
        # Check and see if neighbor is already in the hash 
        if @link_state_packet.neighbors.has_key?([nodes.first, nodes[1]]) == false
          @link_state_packet.neighbors[[nodes.first, nodes[1]]] = nodes[4]
        end 

      # Curent node has no neighbors  
      else 
        # Neighbors should be nil or empty 
      end
    end 
  end

  # --------------------------------------------
  # Determines if the local topology has changed
  # --------------------------------------------
  def has_changed(config_file)
  	# Temporary hash used to hold neighbors
  	# of current node parsed out from file
  	temp_neighbors = Hash.new

    # Parse the config file and look for the
    # information for the current node instance
    File.open(config_file, "r").readlines.each do |line|
    	nodes = line.split(',')

    	# Look for current node in the first index of the line
    	if nodes.first == @source_name
    		temp_neighbors[[nodes[2], nodes[3]]] = nodes[4]

    	# Look for current node in the last index of the line
    	elsif nodes[2] == @source_name
    		temp_neighbors[[nodes.first, nodes[1]]] = nodes[4]

    	# Node not in current line	
    	else
    		# Do nothing
    	end
	end

	# Compare temp_neighbors parsed out to 
	# neighbors in current link state packet
	if  @link_state_packet.neighbors.keys.count == temp_neighbors.keys.count

		@link_state_packet.neighbors.keys.each do |(host, ip)|
			# Continue through loop if the neighbors in the 
			# temp_neighbor match up with the neighbors in the
			# current link state packet
			next if temp_neighbors.has_key?([host, ip]) && @link_state_packet.neighbors[[host, ip]] == temp_neighbors[[host, ip]]

			# Temp neighbors does not match link state
			# packet needs to be updated
			update_packet(temp_neighbors)

			return true
		end

		# If loop finishes without returning true the
		# topology has not changed
		return false
    end

    # Does not match current link state packet
    # needs to be updated
    update_packet(temp_neighbors)

    return true
  end

  # ----------------------------------------
  # This is a helper method used to update 
  # the current link state packet with new
  # params and flood it to the network
  # ----------------------------------------
  def update_packet(new_neighbors)

  	# Increase sequence number of link state packet
	@link_state_packet.seq_numb += 1

	# Update sequence number in link state table
	@link_state_table[@source_name] += 1

	# Update global top
	@global_top.replace_sub_topology(@source_name, @source_ip, new_neighbors)

	# Update neighbors in link state packet
	@link_state_packet.neighbors = new_neighbors

	# Flood network with updated packet
	flood_neighbors(@link_state_packet)

  end

  # ---------------------------------------
  # Utility method used to parse out the 
  # ports that each of the nodes need to 
  # connect to
  # ---------------------------------------
  def parse_port(file)

    # Initialize port hash to store the node names 
    # and the correct ports to run off of
    @port_hash = Hash.new

    
    File.open(file, "r").readlines.each do |line|
      nodes = line.split('=')

      @port_hash[nodes.first] = nodes[1].chomp
    end

    $log.debug("Created port hash #{port_hash.inspect}")

  end    
end


