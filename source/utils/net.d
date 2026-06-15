module utils.net;

import core.thread;
import std, utile, config, core.memory, core.sys.posix.arpa.inet;

import utile.log : Logger;

version (Windows)
{
	import core.sys.windows.winsock2 : fd_set;
	public import core.sys.windows.winsock2 : FD_SET;
}
else
{
	import core.stdc.errno;
	import core.sys.posix.sys.time : timeval;
	import core.sys.posix.sys.select : select, fd_set;
	public import core.sys.posix.sys.select : FD_SET;
}

void checkTunName(string name)
{
	// version (Posix)
	// {
	// 	name.length && name.length < _IFNAMSIZ || throwError!`interface name too long: %s`(name);
	// }

	// FIXME
}

string launch(string[] args...)
{
	auto result = args.execute;
	result.status && throwError!`command %-(%s %) failed with code %d: %s`(args, result.status, result.output);
	return result.output;
}

void routeAdd(string dev, Route r, SubLogger logger)
{
	string route = r.ip.ipToString;

	if (r.prefix != 32)
	{
		route ~= '/' ~ r.prefix.to!string;
	}

	string s = launch(`ip`, `route`, `show`, route);

	if (s.canFind(route))
	{
		logger.info3!`route %s already exists, skip adding`(route);
	}
	else
	{
		logger.info3!`adding route %s`(route);

		launch(`ip`, `route`, `add`, route, `dev`, dev);
	}
}
