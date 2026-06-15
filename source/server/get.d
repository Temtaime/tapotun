module server.get;

import std, utile, server, config, utils, app, packet;
import utile.web, utile.net;

import server.client, server.handler, server.node;

final class MyGet : MyHandler
{
	this(WebConnection conn, NodeClient node)
	{
		super(conn, node);

		conn.responseHeaders[HEADER_TUN] = _node.register(this);

		pp = PacketsWriter(MAX_CACHED_PACKETS_SIZE);
	}

	~this()
	{
		_node.unregister(this);
	}

	override void onResponse()
	{
		conn.send(NETWORK_BUFFERS, (_, data) => onSend(data));
	}

	void terminate()
	{
		_eof = true;
	}

	PacketsWriter pp;
private:
	uint processWrite(ubyte[] buffer)
	{
		size_t total = buffer.length;

		pp.toBuffer(buffer);

		return cast(uint)(total - buffer.length);
	}

	int onSend(ubyte[] buffer)
	{
		if (uint written = processWrite(buffer))
		{
			return written;
		}

		if (_eof)
		{
			return -1; // FIXME: MHD_CONTENT_READER_END_OF_STREAM
		}

		return 0;
	}

	bool _eof;
}
