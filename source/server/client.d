module server.client;

import std, utile, web, server, config, utils, app, packet;

//version = LOG_CLIENTS;

abstract class MyClient : WebClient
{
	this(void* conn, string url, string method, TunServer server)
	{
		super(conn, url, method);

		_server = server;
		_meter = AppTimeMeter.init;
	}

	override void onCreate()
	{
		if (auto p = headers.get(HEADER_KEY, null))
		{
			_r = _server.find(p);

			if (_r)
			{
				version (LOG_CLIENTS)
				{
					logger.info!`[%s] client %s was authorized`(method, client);
				}

				return;
			}
		}

		send(403, `Forbidden`);

		logger.warn!`[SERVER] unauthorized client attempted to connect`;
	}

	override void onComplete()
	{
		if (_r is null)
			return;

		auto d = _meter.elapsed;

		if (d < PREMATURELY_WARNING)
		{
			logger.warn!`[%s] client %s disconnected prematurely after %s`(method, client, d);
		}
		else version (LOG_CLIENTS)
		{
			logger.info!`[%s] client %s disconnected after %s`(method, client, d);
		}
	}

private:
	string client() => _r.net.ipToString;

	Router* _r;
	TunServer _server;
	AppTimeMeter _meter;
}

final:

class MyGet : MyClient
{
	this(void* conn, string url, string method, TunServer server)
	{
		super(conn, url, method, server);

		_ping = AppTimer(PING_INTERVAL);
	}

	override void onCreate()
	{
		super.onCreate();

		if (_r is null)
			return;

		_r.client = this;
		_r.writer.onReset;

		with (_server)
		{
			auto sc = ServerConfig(_conf.mtu, _conf.prefix, _r.net);
			auto data = sc.serializeMem;

			responseHeaders[HEADER_TUN] = Base64.encode(data);
		}

		_timeout = makeTimeout;
	}

	override void onResponse()
	{
		send(NETWORK_BUFFERS);
	}

	override int onSend(ulong /*pos*/ , ubyte[] buffer)
	{
		if (_r.client is this)
		{
			if (uint written = processWrite(buffer))
			{
				_ping.reset;
				return written;
			}

			if (uint written = ping(_ping, buffer))
			{
				return written;
			}

			if (_meter.elapsed < CONNECTION_RESTART)
			{
				return 0;
			}

			logger.info!`restarting writer job due to connection timeout %s`(_timeout);
		}

		return -1; // MHD_CONTENT_READER_END_OF_STREAM
	}

	override void onReceive(in ubyte[] chunk)
	{
		assert(false);
	}

private:
	uint processWrite(ubyte[] buffer)
	{
		uint total = cast(uint)buffer.length;

		with (_server)
		{
			_r.writer.toBuffer(buffer);
		}

		return total - cast(uint)buffer.length;
	}

	AppTimer _ping;
	Duration _timeout;
}

class MyPut : MyClient
{
	this(void* conn, string url, string method, TunServer server)
	{
		super(conn, url, method, server);

		pp = PacketsReader(a => _server.send!true(a, _r));
	}

	override void onResponse()
	{
		send(200, `OK`);
	}

	override int onSend(ulong pos, ubyte[] buf)
	{
		assert(false);
	}

	override void onReceive(in ubyte[] chunk)
	{
		pp.fromBuffer(chunk);
	}

	PacketsReader pp;
}
