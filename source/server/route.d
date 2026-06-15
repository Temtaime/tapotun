module server.route;

import std, utile, utile.tun;
import config;

abstract class Receiver
{
	void send(in ubyte[] packet);
	bool online() const;
}

struct Router
{
	void add(Receiver dst)
	{
		_gw ~= dst;
	}

	void add(Receiver dst, NodeAddr addr)
	{
		_ss ~= SubRouter(addr.ip, prefixToNetmask(32), dst);

		foreach (r; addr.routes)
		{
			_ss ~= SubRouter(r.ip, prefixToNetmask(r.prefix), dst);
		}

		_ss.build;
	}

	void process(in ubyte[] packet, uint dst)
	{
		if (auto rc = find(dst))
		{
			return rc.send(packet);
		}

		Receiver gw;

		foreach (rc; _gw)
		{
			gw = rc;

			if (rc.online) // try to send to online clients first, but if all clients are offline, send to the last one anyway
				break;
		}

		if (gw)
		{
			gw.send(packet);
		}
	}

private:
	Receiver find(uint dst)
	{
		Receiver rc;

		foreach (ref s; _ss)
		{
			if (s.isMatch(dst))
			{
				rc = s.rc;

				if (rc.online)
					break;
			}
		}

		return rc;
	}

	Receiver[] _gw;
	SubRouter[] _ss;
}

struct SubRouter
{
	bool isMatch(uint addr) const => (addr & mask) == net;

	uint net;
	uint mask;

	Receiver rc;
}

void build(SubRouter[] ss)
{
	ss.sort!((a, b) => a.mask > b.mask, SwapStrategy.stable);
}
