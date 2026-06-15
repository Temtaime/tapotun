module server;
import std, std.digest.sha, utile, config, utils, packet, utils.fw;

import utile.net, utile.tun, utile.curl, utile.tun.linux, utile.web, utile.net.headers;

import server.client, server.handler, server.node, server.route;

final:

class TunServer
{
	this(ConfigServer config)
	{
		_conf = config;

		createTun;
		createWebServer;
		createReceivers;

		configureFW(_conf.name);
	}

	~this()
	{
		_web.destroy;
		_tun.destroy;
	}

	void run(ThreeSet ts)
	{
		_clients.byValue.each!(a => a.run);

		while (true)
		{
			if (auto packet = _tun.read)
			{
				if (packetVersion(packet) == 4)
				{
					process(_selves, packet);
				}
			}
			else
				break;
		}

		_runTwice = false;
		_web.run(ts);

		if (_runTwice)
		{
			_web.run(ts); // FIXME: maybe just reduce the timeout of the next run?
		}
	}

	void fdset(ThreeSet ts)
	{
		_web.fdset(ts);
		ts.add(OpIndex.read, _tun.fd);
	}

	@property log() => _tun.log;
package:
	void process(NodeClient node, Blob packet)
	{
		process(_byNode[node], packet);
	}

	void touch()
	{
		_runTwice = true;
	}

private:
	void process(S[] arr, Blob packet)
	{
		// only support IPv4 for now
		assert(packetVersion(packet) == 4);

		auto p = packet.ptr + VNET_HEADER_SIZE;

		uint src = *cast(uint*)(p + 12);
		uint dst = *cast(uint*)(p + 16);

		auto q = arr.find!(a => a.ip == src);
		auto rc = front(q.empty ? arr : q).rc;

		_routes[rc].process(packet, dst);
	}

	void createTun()
	{
		_tun = new LinuxTunDevice(_conf.name, logger);

		auto arr = _conf.self.ips;

		auto settings = TunSettings(arr[0].ip, _conf.network.prefix, _conf.mtu);
		_tun.configure(settings);

		if (_conf.mark)
		{
			_tun.setupFwmark(_conf.mark, _conf.table);
		}

		_tun.assignAddress(arr[1 .. $].map!(a => a.ip).array, _conf.network.prefix);
	}

	void createWebServer()
	{
		_web = new WebServer(_conf.port, CONNECTION_TIMEOUT, log);

		_web.setClientIP(HeaderNormalized.xForwardedFor);

		_web.routes[null][null] = &onConnection;
	}

	void createReceivers()
	{
		Receiver[uint] byIp;

		foreach (p; _conf.self.ips)
		{
			auto rc = new ReceiverServer(_tun);

			auto peers = p
				.peers
				.filter!(a => a.explicit)
				.map!(a => a.addr);

			foreach (peer; peers) // FIXME : maybe just add all the routes ?
			{
				peer.routes.each!(a => routeAdd(_conf.name, a, log));
			}

			byIp[p.ip] = rc;
			_selves ~= S(p.ip, rc);
		}

		foreach (p; _conf.nodes)
		{
			auto sc = ServerConfig(_conf.mtu, _conf.network.prefix);

			foreach (addr; p.ips)
			{
				auto peers = addr
					.peers
					.filter!(a => a.explicit)
					.map!(a => a.addr);

				foreach (r; peers)
				{
					sc.routes ~= r.routes;
				}

				sc.ips ~= addr.ip;
			}

			// config created, now create the client
			auto n = new NodeClient(this, sc, p.name, log);

			foreach (addr; p.ips)
			{
				auto q = addr.ip;
				auto rc = new ReceiverClient(n);

				byIp[q] = rc;
				_byNode[n] ~= S(q, rc);
			}

			_clients[p.token] = n;
		}

		foreach (n; _conf.nodes.chain(_conf.self.only))
		{
			foreach (addr; n.ips)
			{
				Router r;

				foreach (p; addr.peers.map!(a => a.addr)) // FIXME: check if explicit ?
				{
					r.add(byIp[p.ip], p);
				}

				foreach (g; addr.gateway)
				{
					auto gw = byIp[g.ip];
					r.add(gw);
				}

				_routes[byIp[addr.ip]] = r;
			}
		}

		_byNode.rehash;
		_routes.rehash;
	}

	WebHandler onConnection(WebConnection conn)
	{
		if (auto p = HEADER_KEY in conn.headers)
		{
			if (auto node = find(*p))
			{
				return conn.method == Method.put ? new MyPut(conn, node) : new MyGet(conn, node);
			}
		}

		return createHandler403(conn);
	}

nothrow:
	auto find(string token)
	{
		auto hash = token
			.sha1Of
			.toHexString!(LetterCase.lower)
			.idup;

		if (auto p = hash in _clients)
		{
			return *p;
		}

		return null;
	}

	// lookup
	S[] _selves;
	S[][NodeClient] _byNode;

	Router[Receiver] _routes;

	// auth
	NodeClient[string] _clients;

	// clients can send packets to each other, so we have to run web server twice
	bool _runTwice;

	// misc
	ConfigServer _conf;

	WebServer _web;
	LinuxTunDevice _tun;
}

private:

struct S
{
	uint ip;
	Receiver rc;
}

class ReceiverServer : Receiver
{
	this(LinuxTunDevice tun)
	{
		_tun = tun;
	}

	override void send(in ubyte[] packet)
	{
		_tun.write(packet);
	}

	override bool online() const => true;
private:
	LinuxTunDevice _tun;
}
