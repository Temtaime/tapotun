module config.parsers;

import std, utile, utils;
import utile.net;
import config.constants;
import config.structs;

TunConfigBase[] parseConfig(string path)
{
	TunConfigBase[] result;

	auto json = path
		.readText
		.parseJSON;

	foreach (item; json.array)
	{
		TunConfigBase conf;

		if (`port` in item)
		{
			conf = parseServerConfig(name, item);
		}
		else
			conf = parseClientConfig(item);

		conf.name = item[`name`].str;

		checkTunName(conf.name);
		parseMark(conf, item);

		result ~= conf;
	}

	logger.info2!`loaded %d tunnel configurations`(result.length);
	return result;
}

private:

Route parseRoute(string s)
{
	auto parts = s.split('/');
	parts.length < 3 || throwError!`invalid route %s`(s);

	Route route;
	route.ip = parts[0].parseIp;
	route.prefix = parts.length == 2 ? parts[1].to!ubyte : 32;
	return route;
}

void parseMark(TunConfigBase conf, JSONValue json)
{
	if (auto m = `mark` in json)
	{
		conf.mark = cast(uint)(*m)[`value`].integer;
		conf.table = cast(uint)(*m)[`table`].integer;
	}
}

ConfigClient parseClientConfig(JSONValue json)
{
	auto conf = new ConfigClient;

	conf.token = json[`token`].str;
	conf.server = json[`server`].str;

	return conf;
}

NodeAddr[] collect(string name, JSONValue j, NodeAddr[][string] byTag)
{
	NodeAddr[] result;

	if (j.type == JSONType.string)
	{
		bool ok;
		string tag = j.str;

		foreach (k, arr; byTag)
		{
			if (k.globMatch(tag))
			{
				result ~= arr;
				ok = true;
			}
		}

		ok || throwError!`tag %s not found in config while parsing %s`(tag, name);
	}
	else
	{
		foreach (r; j.array)
		{
			result ~= collect(name, r, byTag);
		}
	}

	return result;
}

void processIp(Node node, JSONValue jn, JSONValue j, ref Node[NodeAddr] byIp, ref NodeAddr[][string] byTag)
{
	auto addr = new NodeAddr;
	string ipStr;

	if (j.type == JSONType.string)
	{
		ipStr = j.str;
		addr.ip = ipStr.parseIp;
	}
	else if (j.type == JSONType.object)
	{
		ipStr = j[`ip`].str;
		addr.ip = ipStr.parseIp;

		// lookup only in the same object
		jn = j;
	}

	addr in byIp && throwError!`node %s has duplicate IP %s in config`(node.name, ipStr);
	byIp[addr] = node;

	if (auto r = `routes` in jn)
	{
		if (r.type == JSONType.string)
		{
			addr.routes ~= parseRoute(r.str);
		}
		else
			addr.routes = r.array.map!(a => parseRoute(a.str)).array;
	}

	if (auto r = `tags` in jn)
	{
		if (r.type == JSONType.string)
		{
			byTag[r.str] ~= addr;
		}
		else
			r.array.each!(a => byTag[a.str] ~= addr);
	}

	byTag[`node/` ~ node.name] ~= addr;
	node.ips ~= addr;
}

ConfigServer parseServerConfig(string name, JSONValue json)
{
	auto conf = new ConfigServer;

	conf.port = cast(ushort)json[`port`].integer;
	conf.network = json[`network`].str.parseRoute;

	if (auto m = `mtu` in json)
	{
		conf.mtu = cast(ushort)m.integer;
		checkMtu(conf.mtu);
	}
	else
		conf.mtu = DEFAULT_MTU;

	Node[NodeAddr] byIp;
	NodeAddr[][string] byTag;

	foreach (nodeName, jn; json[`nodes`].object)
	{
		auto node = new Node;
		node.name = nodeName;

		if (nodeName == `__self__`)
		{
			conf.self = node;
		}
		else
		{
			node.token = jn[`token`].str;
			conf.nodes.map!(a => a.token).canFind(node.token) && throwError!`duplicate token %s in config`(node.token);

			conf.nodes ~= node;
		}

		if (auto q = `ip` in jn)
		{
			processIp(node, jn, *q, byIp, byTag);
		}
		else
		{
			foreach (jp; jn[`ips`].array)
			{
				processIp(node, jn, jp, byIp, byTag);
			}
		}
	}

	conf.self || throwError!`__self__ node not found in %s`(name);

	void add(NodeAddr src, NodeAddr dst, bool explicit)
	{
		bool same = byIp[src] is byIp[dst];

		if (same)
		{
			return;
		}

		auto arr = src.peers.find!(a => a.addr is dst);

		if (arr.empty)
		{
			src.peers ~= Peer(dst, explicit);
		}
		else
			arr[0].explicit |= explicit;
	}

	if (auto q = `acl` in json)
	{
		foreach (je; q.array)
		{
			auto sources = collect(`acl`, je[`from`], byTag);
			auto destinations = collect(`acl`, je[`to`], byTag);

			foreach (src; sources)
			{
				foreach (dst; destinations)
				{
					add(src, dst, true);
					add(dst, src, false);
				}
			}
		}
	}

	if (auto q = `exit_nodes` in json)
	{
		foreach (je; q.array)
		{
			auto sources = collect(`exit_nodes`, je[`from`], byTag);
			auto destinations = collect(`exit_nodes`, je[`via`], byTag);

			foreach (src; sources)
			{
				foreach (dst; destinations)
				{
					dst is src && throwError!`node %s cannot be an exit node of itself`(byIp[src].name);

					if (src.gateway.canFind(dst))
					{
						throwError!`node %s cannot have duplicate exit node %s`(byIp[src].name, byIp[dst].name);
					}

					src.gateway ~= dst;
					dst.peers ~= Peer(src, false);
				}
			}
		}
	}

	return conf;
}
