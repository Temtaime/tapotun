module config;
import std, utile, utils;

// common
enum NETWORK_BUFFERS = 256 * 1024;
enum MAX_CACHED_PACKETS_SIZE = 12 * 1024 * 1024;

enum PACKET_DELAY = 100; // ms
enum PING_INTERVAL = 55.seconds;

enum CONNECTION_TIMEOUT = 91.minutes;

enum CONNECTION_RESTART = 60.minutes;
enum CONNECTION_RESTART_JITTER = 30.minutes; // from -30 to +30 minutes

// server
enum PREMATURELY_WARNING = 30.seconds;

// client
enum CLIENT_DELAY_ERROR_MIN = 3; // seconds
enum CLIENT_DELAY_ERROR_MAX = 10; // seconds

// app
enum LOOP_DELAY = 1.seconds;
enum UPDATE_CHECK_INTERVAL = 1.minutes;

enum HEADER_KEY = `x-api-key`;
enum HEADER_TUN = `x-tun-conf`;

// misc
enum DEFAULT_MTU = 1500;

struct Route
{
	uint ip;
	ubyte prefix;
}

struct Mark
{
	uint value;
	uint table;
}

struct TunClientConfig
{
	string token;
	uint ip;
	Route[] routes;
	uint[] sources;
}

struct ServerConfig
{
	ushort mtu;
	ubyte prefix;
	uint ip;
}

struct TunConfig
{
	// common:
	string name; // TUN interface name
	Mark mark;

	// client:
	string token;
	string server;

	// server:
	ushort port;
	uint ip;
	ubyte prefix;
	ushort mtu;
	uint[] ips;
	TunClientConfig[] clients;
	Route[] routes;
}

auto makeTimeout()
{
	auto e = CONNECTION_RESTART_JITTER.toSecs;

	return CONNECTION_RESTART + uniform(-e, e).seconds;
}

auto parseRoutes(JSONValue json)
{
	Route[] routes;

	if (auto p = `routes` in json)
	{
		foreach (r; p.array)
		{
			auto parts = r.str.split(`/`);
			parts.length == 2 || throwError!`invalid route %s`(r.str);

			Route route;
			route.ip = parts[0].parseIp;
			route.prefix = parts[1].to!ubyte;

			routes ~= route;
		}
	}

	return routes;
}

void parseMark(ref TunConfig tun, JSONValue json)
{
	if (auto m = `mark` in json)
	{
		tun.mark.value = cast(uint)(*m)[`value`].integer;
		tun.mark.table = cast(uint)(*m)[`table`].integer;
	}
}

auto parseConfig(string path)
{
	TunConfig[] tuns;

	auto json = path
		.readText
		.parseJSON;

	foreach (tunJson; json.array)
	{
		TunConfig tun;

		tun.name = tunJson[`name`].str;
		checkTunName(tun.name);

		// parse optional mark field
		parseMark(tun, tunJson);

		if (auto p = `port` in tunJson)
		{
			tun.port = cast(ushort)p.integer;

			{
				auto net = tunJson[`net`].str;

				auto parts = net.split(`/`);
				parts.length == 2 || throwError!`invalid network %s`(net);

				tun.ip = parts[0].parseIp;
				tun.prefix = parts[1].to!ubyte;
			}

			// parse server MTU
			if (auto m = `mtu` in tunJson)
			{
				tun.mtu = cast(ushort)m.integer;
				checkMtu(tun.mtu);
			}
			else
				tun.mtu = DEFAULT_MTU;

			// parse optional ips field
			if (auto ips = `ips` in tunJson)
			{
				foreach (ip; ips.array)
				{
					tun.ips ~= ip.str.parseIp;
				}
			}

			// parse server clients
			foreach (clientJson; tunJson[`clients`].array)
			{
				TunClientConfig client;
				client.token = clientJson[`token`].str;
				client.ip = clientJson[`ip`].str.parseIp;

				// parse optional routes field
				client.routes = parseRoutes(clientJson);

				// parse optional sources field
				if (auto s = `sources` in clientJson)
				{
					foreach (ip; s.array)
					{
						client.sources ~= ip.str.parseIp;
					}
				}

				tun.clients ~= client;
			}

			tun.routes = parseRoutes(tunJson);
		}
		else
		{
			tun.token = tunJson[`token`].str;
			tun.server = tunJson[`server`].str;
		}

		tuns ~= tun;
	}

	logger.info2!`loaded %d tunnel configurations`(tuns.length);
	return tuns;
}
