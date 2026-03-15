module tun;
import std, utile, core.stdc.errno, utils;

import core.sys.posix.time;

import tun.linux;
import tun.sys : read_ = read, write_ = write, close_ = close;

//version = DEBUG_TUN;

enum MIN_PACKET = 20;
enum MAX_PACKET = ushort.max;

enum VNET_HEADER_SIZE = 12;

enum MIN_FRAME = VNET_HEADER_SIZE + MIN_PACKET; // min IP packet + VNET header size
enum MAX_FRAME = VNET_HEADER_SIZE + MAX_PACKET; // max MTU + VNET header size

class TunDevice
{
	this(string name)
	{
		logger.info!`creating %s`(name);

		version (Posix)
		{
			createTun(_fd = openTun, _name = name);
		}
	}

	~this()
	{
		logger.info!`closing %s`(_name);

		close_(_fd);
	}

	void configure(Settings s)
	{
		if (_s != s)
		{
			logger.info!`configuring %s with MTU %u, IP %s/%u`(_name, s.mtu, s.ip.ipToString, s.prefix);

			version (Posix)
			{
				configureTun(_name, s.ip, s.prefix, s.mtu);
			}

			_s = s;
		}
	}

	void write(const(ubyte)[] data)
	{
		version (DEBUG_TUN)
		{
			logger.info3!`writing %u bytes to %s`(data.length, _name);
		}

		while (true)
		{
			int len = cast(int)data.length;
			int written = cast(int)write_(_fd, data.ptr, len);

			if (written == len)
				break;
			else
				errno == EAGAIN || throwError!`error %d writing to %s, data length %u, written %d`(errno, _name, len, written);

			version (Posix)
			{
				auto ts = timespec(0, 500_000);
				nanosleep(&ts, null);
			}
		}
	}

	ubyte[] read()
	{
		int bytesRead = cast(int)read_(_fd, _buf.ptr, cast(uint)_buf.length);

		if (bytesRead <= 0)
		{
			errno == EAGAIN || throwError!`error %d reading from %s, buffer length %u, bytes read %d`(errno, _name, _buf.length, bytesRead);
			return null;
		}

		version (DEBUG_TUN)
		{
			logger.info3!`read %u bytes from %s`(bytesRead, _name);
		}

		assert(bytesRead >= MIN_FRAME && bytesRead <= MAX_FRAME);

		return _buf[0 .. bytesRead];
	}

private:
	mixin publicProperty!(int, `fd`);

	Settings _s;
	string _name;

	ubyte[MAX_FRAME + 1] _buf; // +1 to be able to detect if packet is too big for buffer
}

struct Settings
{
	uint ip;
	ubyte prefix;
	ushort mtu;
}
