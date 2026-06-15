module config.structs;

import utile;

struct Route
{
	uint ip;
	ubyte prefix;
}

// wire format sent to the client on GET (serialized by the server)
struct ServerConfig
{
	ushort mtu;
	ubyte prefix;

	@(ArrayLength!ubyte) uint[] ips;
	@(ArrayLength!ubyte) Route[] routes;
}

abstract class TunConfigBase
{
	string name;

	uint mark;
	uint table;
}

struct Peer
{
	NodeAddr addr;
	bool explicit; // FIXME: we push routes only for explicit peers
}

final:

class NodeAddr
{
	uint ip;
	Route[] routes;

	Peer[] peers; // destination nodes this addr is allowed to send to
	NodeAddr[] gateway; // exit nodes in priority order
}

class Node
{
	string name;
	string token; // empty for __self__

	NodeAddr[] ips;
}

class ConfigServer : TunConfigBase
{
	ushort mtu;
	ushort port;

	Route network;

	Node self; // __self__ node
	Node[] nodes; // client nodes
}

class ConfigClient : TunConfigBase
{
	string token;
	string server;
}
