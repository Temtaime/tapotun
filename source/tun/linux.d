module tun.linux;

import std.process, std.conv, utile, core.stdc.errno, tun, tun.sys, utils;

void assignAddress(string name, uint[] ips, ubyte prefix)
{
	foreach (ip; ips)
	{
		auto s = ip.ipToString;
		auto cmd = [`ip`, `addr`, `add`, s ~ `/` ~ prefix.to!string, `dev`, name];

		logger.info2!`adding IP %s/%u to %s`(s, prefix, name);

		auto result = execute(cmd);
		result.status && throwError!`failed to add IP %s to %s: %s`(s, name, result.output);
	}
}

void setupFwmark(string name, uint value, uint table)
{
	auto tableStr = table.to!string;
	auto mark = value.to!string;

	logger.info2!`setting up fwmark %u routing for %s (table %u)`(value, name, table);

	// clean table
	[`ip`, `route`, `flush`, `table`, tableStr].execute;

	// add route
	{
		auto result = [`ip`, `route`, `add`, `default`, `dev`, name, `table`, tableStr].execute;

		result.status && throwError!`failed to add route for %s: %s`(name, result.output);
	}

	// clean fwmark
	[`ip`, `rule`, `del`, `fwmark`, mark, `table`, tableStr].execute;

	// add fwmark
	{
		auto result = [`ip`, `rule`, `add`, `fwmark`, mark, `table`, tableStr].execute;

		result.status && throwError!`failed to add rule for fwmark %u: %s`(value, result.output);
	}
}

version (linux)
{
	int openTun()
	{
		int fd = open(`/dev/net/tun`, O_RDWR | O_NONBLOCK);
		fd >= 0 || throwError!`failed to open /dev/net/tun`;
		return fd;
	}

	void doIoctl(int fd, int op, void* arg)
	{
		ioctl(fd, op, arg) >= 0 || throwError!`ioctl %d failed with error %d`(op, errno);
	}

	auto makeIfr(string name)
	{
		ifreq ifr;

		with (ifr.ifr_ifrn)
		{
			ifrn_name[0 .. name.length] = name[];
			ifrn_name[name.length] = 0;
		}

		return ifr;
	}

	void createTun(int fd, string name)
	{
		ifreq ifr = makeIfr(name);

		with (ifr.ifr_ifru)
		{
			ifru_flags = IFF_TUN | IFF_NO_PI | IFF_VNET_HDR;
		}

		ioctl(fd, _TUNSETIFF, &ifr) >= 0 || throwError!`failed to create TUN device with name %s`(name);

		{
			uint vnetHdrSize = VNET_HEADER_SIZE;

			ioctl(fd, _TUNSETVNETHDRSZ, &vnetHdrSize) >= 0 || throwError!`failed to set VNET header size`;
		}

		{
			uint flags = _TUN_F_CSUM | _TUN_F_TSO_ECN;

			flags |= _TUN_F_TSO4 | _TUN_F_TSO6;
			//flags |= _TUN_F_USO4 | _TUN_F_USO6;

			ioctl(fd, _TUNSETOFFLOAD, flags) >= 0 || throwError!`failed to enable offload features, error %d`(errno);
		}
	}

	void configureTun(string name, uint ip, ubyte prefix, ushort mtu)
	{
		auto ifr = makeIfr(name);

		// Now set MTU, IP address, netmask, and bring it up
		int sock = socket(_AF_INET, SOCK_DGRAM, 0);
		sock >= 0 || throwError!`failed to create socket for TUN configuration`;

		scope (exit)
		{
			close(sock);
		}

		with (ifr.ifr_ifru)
		{
			// MTU
			ifru_mtu = mtu;
			doIoctl(sock, SIOCSIFMTU, &ifr);

			// IPv4 address
			*cast(sockaddr_in*)&ifru_addr = sockaddr_in(_AF_INET, 0, in_addr(ip));

			doIoctl(sock, SIOCSIFADDR, &ifr);

			// Netmask
			*cast(sockaddr_in*)&ifru_netmask = sockaddr_in(_AF_INET, 0, in_addr(prefixToNetmask(prefix)));

			doIoctl(sock, SIOCSIFNETMASK, &ifr);

			// UP flag
			// Need to re-fetch flags first.
			doIoctl(sock, SIOCGIFFLAGS, &ifr);

			ifru_flags |= IFF_UP;

			doIoctl(sock, SIOCSIFFLAGS, &ifr);
		}
	}
}
