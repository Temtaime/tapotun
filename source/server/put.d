module server.put;

import std, utile, server, config, utils, app, packet;
import utile.web, utile.net;

import server.client, server.handler, server.node;

final class MyPut : MyHandler
{
	this(WebConnection conn, NodeClient node)
	{
		super(conn, node);

		_node.register(this);

		pp = PacketsReader(&node.receive);
	}

	~this()
	{
		_node.unregister(this);
	}

	override void onResponse()
	{
		conn.send(200, `OK`);
	}

	override void onReceive(in ubyte[] chunk)
	{
		pp.fromBuffer(chunk);
	}

	PacketsReader pp;
}
