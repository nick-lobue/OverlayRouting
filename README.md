Note to TA: Don't read this. Read readme.txt instead


# OverlayRouting


PART 1: Routing Tables
(rough outline of this section)



Run.sh
Called first passes configuration file to main ruby runnable


Main Ruby Script:
Flood the network with local topologies
Utilize tcp sockets to send local topologies to all neighbors of the current node (Flooding Utility)
Construct global topology (Graph Builder)
Run Dijkstras on global topology to create routing tables (Dijkstra Executor)
Keeps track of system clock time
Handles all thread management
Main thread - listens for user commands from STDIN and creates the 3 threads below
Thread 1 - listens on a port for incoming transmissions that’ll then be passed on to the worker threads
Thread 2 - captures the node’s internal clock and then keeps it updated for the program’s lifetime
Thread 3 - reads in from configuration file for neighbor cost information and floods network with packets (Flooding Utility), reconstructs network topology graph (Graph Builder), updates routing table (Dijkstra Executor)
Worker threads - created by Thread 1, these will each handle a new operation that has been received


Link State Packet:
Defines the data that’ll be flooded throughout the network by each node.

Fields include:
sourceName - hostname of the source that sent the packet
sourceIP - ip address of the source that sent the packet
Local topology - structure holding the source’s neighbors and the costs to these neighbors
Sequence number - integer used to determine when to accept or discard this packet at any given node



Flooding Utility
Read in from configuration file that specifies outgoing links and their costs.
Need to create Link State Packets that will help carry out a controlled flooding algorithm
Need a table to keep track of each sender with its sequence number
Will only forward a flooding packet if it has never seen it before (discard packet)
Nodes will only forward each packet once
How to know when flooding is done?


Graph Builder:
Constructs and maintains a graph structure to resemble the network’s topology.
Inner classes:
GraphNode:
Fields included:
hostname - hostname of this node
ipAddress - ip address of this node
neighbors - set of GraphEdges describing the neighbors and link costs
GraphEdge:
Fields included:
endNode - GraphNode object corresponding to the end point of the edge
edgeCost - number containing the cost of this edge (from firstNode to secondNode)


Dijkstra Executor:
Runs Dijkstra’s algorithm on the graph (created by Graph Builder) that is provided and returns a hash table (Ruby Hash) that represents the routing table for the current node.
Routing table:
keys - destination node’s hostname
values - next hop in the path to arrive at the destination node (key)
Helpful stuff to read:
Core documenation: http://downloads.pf.itd.nrl.navy.mil/docs/core/core-html/
http://downloads.pf.itd.nrl.navy.mil/docs/core/core-html/scripting.html
http://ruby-doc.org/stdlib-1.9.3/libdoc/socket/rdoc/Socket.html

