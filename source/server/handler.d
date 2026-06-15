module server.handler;

import std, utile, server, config, utils, app, packet;
import utile.web, utile.net;

import server.client, server.node;

public import server.get;
public import server.put;

package:

abstract class MyHandler : WebHandler
{
	this(WebConnection conn, NodeClient node) nothrow
	{
		super(conn);

		_node = node;
	}

protected:
	NodeClient _node;
}
