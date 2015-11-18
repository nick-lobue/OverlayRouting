require 'socket'
require 'link_state_packet'

class FloodingUtil
  
  attr_accessor :source_name, :source_ip, :link_state_packet, :link_state_table

  # ------------------------------------------------
  # Initialize the flooding util with the info
  # needed for the link state packet
  # ------------------------------------------------
  def initialize(source_name, source_ip, config_file)
    
    # Set source name field which marks
    # instance of node the flooding util 
    # is running on
    @source_name = source_name
    @source_ip = source_ip
    

    # Initialize link state table and insert
    # current source name and sequence number
    @link_state_table = Hash.new
    @link_state_table[@source_name] = 0

    # Parse config file and set fields for
    # link state instance
    @link_state_packet = LinkStatePacket.new(sourceName, source_ip, 0)
    parse_config(config_file)

    # Construct initial graph based on 
    # the neighbors specified in the 
    # configuration file 
    
    
  end

  # ------------------------------------------------
  # This utility method will be used to send the
  # current link state packet to its neighbors 
  # ------------------------------------------------
  def flood_neighbors

    # TODO - Use tcp sockets to send out the link
    # state packet to all of its neighbors
    @link_state_packet.neighbors.each do |neighbor|
        # Send packet 
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
      @link_state_table[ls_packet.source_name] = ls_packet.seqNumb
      # Build graph
    
    # If link state is already in the table check its seq numb
    # against the recieved link state packet if it did change 
    # we want to update the table and flood
    elsif @link_state_table[ls_packet.source_name] != ls_packet.seq_numb 
      # Update lsp and topology ls table and flood
    
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
    
    File.open(config_file, "r").readlines.each.do |line|
      nodes = line.split(',')

      # Check if the first node is listed in the line
      # is the current node being run on
      if nodes.first == @source_name
        # Check and see if neighbor is already in the hash
        if @link_state_packet.neighbors.has_key([nodes[2], nodes[3]])? == false
          @link_state_packet.neighbors[[nodes[2], nodes[3]]] = nodes[4]
        end 
       
      # Check if the third node listed in line is the
      # node being run on
      elsif nodes[2] == @source_name
        # Check and see if neighbor is already in the hash 
        if @link_state_packet.neighbors.has_key([nodes.first, nodes[1]])? == false
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
    # Parse the config file and look for the
    # information for the current node instance
    
    # Check the parsed information agaisnt the
    # current link state packet instance
    # if the neighbors have changed we want to
    # update the instance with the new neighbors, 
    # its seq number, and its seq numb in the table
    # this method will return true in this case and
    # false otherwise
    return true

  end   

end
