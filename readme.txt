How to run:

./run.sh <config-path> <hostname>
e.g. "./run.sh pa3.r-scenarios/s1/config n1"

how to run onion routing:
TOR <hostname> <message>

e.g. "TOR n3 hello"
message may not have whitespect


Our code (from our presentation)

3 blocking queues and a packet listener 
packet listener listens for packets using a TCP server and inspects it’s type pushing it to it’s appropriate queue.
A forward queue that accepts outgoing packets and forwards it to other nodes.
A control message queue that accepts incoming control message packets, processes it, then pushes it on the forward queue.
A link state queue that accepts incoming link state packets, processes it, then pushes it on the forward queue.
Threads
A thread for each queue discussed above
Routing table updates
A thread listening for commands from user. Generating initial control message packet if needed.

Node time is continuously updated in its own thread by sleeping for 1 millisecond and then adding 1 millisecond to a time variable.
CLOCKSYNC is called recurringly in its own thread by sleeping the number of seconds specified by ‘updateInterval’ and then executing the job. This is used to keep times more consistent across nodes and is useful when running other control message operations.
Cristian’s algorithm:
Node communicates with its neighbors to determine if its time is behind. If so, the node updates its time variable by setting its value to (neighbors_time) + (round_trip_time / 2).
Primarily used in low latency networks.
Synchronization of clocks are accurate if the request’s round-trip times are short.

ADVERTISE
Each node that the ADVERTISE message travels to stores a subscription table in the format below
POST
POST proposed problems due to the fact that flooding was prohibited. Every node does not know the subscription table. (POST called from a node outside the subscription may not know where to go)
To tackle this issue we randomly go through the routing tables and check for a node that knows of the subscription. 
This implementation may be reasonable for this project, however, we are exploring other solutions that could be applied more generally.


FTP: read files in binary using IO.binread, encode to base64, and pass into payload along with size. Decode from base64 and write binary into file. Check if final file size matches size given in payload.
Traceroute: Each node writes it’s time to payload[“last_node_time”] appends its print statement to payload[“data”]. Source node prints payload[“data”].
Send Message:  Each node forwards the message until destination is reached. Destination appends info to the payload so the source node can determine if it was successfully received.
Ping: When a destination node is reached the message is sent back to source and round trip time is calculated at source.
Timeout: Timeouts for control messages are enforced by a timeout hash where packets have unique ids and a separate thread that updates this hash to clear out any packets that have exceeded a maximum time threshold.

Onion routing

Each node has an asymmetric public key and private key.
The asymmetric public key is distributed in the link state packet.
Each node has every node’s asymmetric public key available in a public key table.
We used 2048 bit RSA (yeah yeah I know don’t use RSA in the real world)

A symmetric key and control message packet is created for each node.
These control message packets are meant to be unwrapped and forwarded to the next hop in the chain.
The source address is the current hop and the destination address is the next hop in the chain.
The control message packet contains the next node’s symmetric key and iv. However they are encrypted using the next node’s asymmetric public key.
Each control message packet is put into payload[“TOR”][“next_cmp”]
The lowest layer control message packet’s payload actually contains the message.
	payload[“TOR”][“message”] equals the tor message
payload[“TOR”] is then encrypted with the next hop’s generated symmetric key.
Anything payload[“TOR”] contains such as the control message packets, message, and complete flag can only be decrypted by the next_hop’s generated symmetric key.


When an onion is received:
The current node decrypts the symmetric key and iv using it’s private asymmetric key.
It then decrypts payload[“TOR”] using the symmetric key and iv
If payload[“complete”] == true we extract the message and print to stdout.
else we get the next control message packet located in tor_payload[“next_cmp”]
We then forward it.


