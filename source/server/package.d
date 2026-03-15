module server;
import std, std.digest.sha, utile, tun, tun.linux, web, config, utils, packet;

import server.client;

class TunServer
{
	this(TunConfig config)
	{
		logger.info!`[SERVER] starting server %s on port %u`(config.name, config.port);

		// create web server
		_web = new WebServer(config.port);
		_web.createClient = &createClient;

		// create TUN device
		_tun = new TunDevice(config.name);
		_tun.configure(Settings(config.ip, config.prefix, config.mtu));

		assignAddress(config.name, config.ips, config.prefix);

		if (config.mark.value)
		{
			setupFwmark(config.name, config.mark.value, config.mark.table);
		}

		// store config
		_conf = config;

		// create routers
		foreach (c; _conf.clients)
		{
			_routers ~= Router(c.ip, 32, null);
		}

		foreach (i, c; _conf.clients)
		{
			auto w = _routers[i].writer;

			foreach (route; c.routes)
			{
				_routers ~= Router(route.ip, route.prefix, w);
			}

			foreach (ip; c.sources)
			{
				_sources[ip] = w;
			}
		}

		foreach (n; _conf.routes)
		{
			_nets ~= MRouter(n.ip, n.prefix);
		}

		sort!((a, b) => a.mask > b.mask, SwapStrategy.stable)(_nets);
		sort!((a, b) => a.mask > b.mask, SwapStrategy.stable)(_routers);
	}

	~this()
	{
		_web.destroy;
		_tun.destroy;
	}

	void run(ref Selector s)
	{
		_routers.each!(a => a.writer.removeOutdated);

		while (true)
		{
			if (auto data = _tun.read())
			{
				send!false(data, null);
			}
			else
				break;
		}

		_wasC2C = false;
		_web.run(s);

		if (_wasC2C) // FIXME: maybe just skip the delay in the app's loop ?
		{
			_web.run(s);
		}
	}

	void fdset(ref Selector s)
	{
		_web.fdset(s);

		FD_SET(_tun.fd, s.read);
		s.add(_tun.fd);
	}

package:
	void send(bool Client)(in ubyte[] packet, Router* client)
	{
		static if (Client)
		{
			if (packet.empty) // ping
			{
				pong;
				return;
			}
		}

		assert(packet.length >= MIN_FRAME && packet.length <= MAX_FRAME);

		auto p = packet.ptr + VNET_HEADER_SIZE;
		auto ver = p[0] >> 4;

		if (ver != 4)
			return;

		auto destIp = *cast(uint*)(p + 16);

		foreach (ref r; _routers)
		{
			static if (Client)
			{
				if (r.writer is client.writer)
					continue;
			}

			if (r.isMatch(destIp))
			{
				static if (Client)
				{
					_wasC2C = true;
				}

				return r.writer.add(packet);
			}
		}

		auto srcIp = *cast(uint*)(p + 12);

		if (auto w = _sources.get(srcIp, null))
		{
			bool b = true;

			static if (Client)
			{
				if (destIp == _conf.ip)
				{
					b = false;
				}
				else
					foreach (ref n; _nets)
					{
						if (n.isMatch(destIp))
						{
							b = false;
							break;
						}
					}
			}

			if (b)
			{
				static if (Client)
				{
					_wasC2C = true;
				}

				return w.add(packet);
			}
		}

		static if (Client)
		{
			_tun.write(packet);
		}
	}

	auto find(string token)
	{
		auto hash = token
			.sha1Of
			.toHexString
			.toLower
			.idup;

		foreach (i, ref c; _conf.clients)
		{
			if (c.token == hash)
			{
				return &_routers[i];
			}
		}

		return null;
	}

	WebClient createClient(void* conn, string url, string method)
	{
		if (method == `PUT`)
		{
			return new MyPut(conn, url, method, this);
		}

		return new MyGet(conn, url, method, this);
	}

	bool _wasC2C;

	TunDevice _tun;
	TunConfig _conf;

	MRouter[] _nets;

	WebServer _web;
	Router[] _routers;
	PacketsWriter*[uint] _sources;
}

struct MRouter
{
	@disable this();

	this(uint ip, ubyte prefix)
	{
		net = ip;
		mask = prefixToNetmask(prefix);
	}

	bool isMatch(uint addr) const => (addr & mask) == net;

	uint net;
	uint mask;
}

struct Router
{
	@disable this();

	this(uint ip, ubyte prefix, PacketsWriter* writer_)
	{
		route = MRouter(ip, prefix);
		writer = writer_ ? writer_ : new PacketsWriter(MAX_CACHED_PACKETS_SIZE);
	}

	MRouter route;
	alias route this;

	MyGet client;
	PacketsWriter* writer;
}
