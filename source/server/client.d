module server.client;

import std, utile, utile.tun;
import packet, config, utils;

import utile.log : Logger, SubLogger;

import server, server.handler, server.route, server.node;

final class ReceiverClient : Receiver
{
	this(NodeClient node)
	{
		_node = node;
	}

	override void send(in ubyte[] packet)
	{
		_node.send(packet);
	}

	override bool online() const => _node.online;
private:
	NodeClient _node;
}
