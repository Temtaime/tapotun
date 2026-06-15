module server.node;

import std, utile, utile.tun;
import packet, config, utils;

import utile.log : Logger, SubLogger;

import server, server.handler, server.route;

final class NodeClient
{
	this(TunServer server, ServerConfig conf, string name, LoggerBase parent)
	{
		_server = server;
		_conf = Base64.encode(conf.serializeMem);

		logger = new SubLogger(parent, `node:` ~ name);
	}

	void send(in ubyte[] packet)
	{
		if (_out)
		{
			_out.pp.add(packet);
		}

		// make sure the server will run twice to send packets to clients
		_server.touch;
	}

	void run()
	{
		if (appTime.now >= _nextPing)
		{
			doPing;
		}

		if (_out)
		{
			_out.pp.removeOutdated;
		}
	}

	bool online() const => _penalty < appTime.now;

	SubLogger logger;
package:
	string register(MyGet r)
	{
		if (_out)
		{
			_out.terminate;
		}

		_out = r;
		_nextPing = appTime.now + PING_INTERVAL_LONG;

		return _conf;
	}

	void unregister(MyGet r)
	{
		if (_out is r)
		{
			_out = null;
		}
	}

	void register(MyPut p)
	{
		_inp = p;
	}

	void unregister(MyPut p)
	{
		if (_inp is p)
		{
			_inp = null;
		}
	}

	void receive(in ubyte[] packet)
	{
		ubyte ver = packetVersion(packet);

		if (ver == 1)
		{
			onPong(packet);
		}
		else
		{
			_server.process(this, packet);
		}
	}

private:
	auto calculatePing() const
	{
		Duration[CLIENT_PING_COUNT] arr = _pings;

		arr[].sort;
		auto rest = arr[0 .. CLIENT_PING_TOP_COUNT];

		return rest.sum / rest.length;
	}

	void evaluatePing()
	{
		auto rtt = calculatePing;

		if (rtt < CLIENT_PING_THRESHOLD)
		{
			return;
		}

		if (online)
		{
			logger.warn!`client ping is too high: %s, disabling this exit node`(rtt);
		}

		_penalty = appTime.now + CLIENT_PING_PENALTY;
	}

	void newPing()
	{
		auto arr = _pings[];

		if (arr[0] == CLIENT_PING_UNKNOWN) // last ping is unknown, use short interval to detect if client is offline
		{
			_nextPing = appTime.now + PING_INTERVAL_SHORT;
		}
		else
		{
			_nextPing = appTime.now + PING_INTERVAL_LONG;
		}

		bringToFront(arr.drop(1), arr.take(1));
		arr[0] = CLIENT_PING_UNKNOWN;

		send(makePingPacket);
	}

	void doPing()
	{
		evaluatePing;
		newPing;
	}

	void onPong(Blob packet)
	{
		auto rtt = calculateRtt(packet);

		logger.info3!`received pong, RTT = %s`(rtt);

		_pings[0] = rtt;
	}

	// network
	MyPut _inp;
	MyGet _out;

	// ping
	MonoTime _penalty;
	MonoTime _nextPing;
	Duration[CLIENT_PING_COUNT] _pings;

	// misc
	string _conf;
	TunServer _server;
}
