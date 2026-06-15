module utils;
import std, utile, core.memory, core.sys.posix.arpa.inet, core.thread;

import utile.tun;

public import utils.mem;
public import utils.net;

import config, packet;

enum PING_PROTO_VERSION = 1;

ubyte packetVersion(Blob packet)
{
	auto p = packet.ptr + VNET_HEADER_SIZE;
	return p[0] >> 4;
}

auto makePingPacket()
{
	auto data = new ubyte[SLOW_SPEED_THRESHOLD * 60]; // should be larger than MIN_FRAME

	auto p = data.ptr + VNET_HEADER_SIZE;
	p[0] = PING_PROTO_VERSION << 4;

	*cast(ulong*)(p + 1) = Clock.currStdTime;
	return data;
}

auto calculateRtt(Blob packet)
{
	auto p = packet.ptr + VNET_HEADER_SIZE + 1;
	ulong time = *cast(ulong*)p;
	return hnsecs(Clock.currStdTime - time);
}
