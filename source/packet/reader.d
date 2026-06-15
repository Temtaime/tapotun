module packet.reader;

import packet;
import std, utile, app, config;

import utile.tun;

struct PacketsReader
{
	this() @disable;

	this(void delegate(in ubyte[] packet) handler) nothrow
	{
		onReset;
		_handler = handler;
	}

	void onReset() nothrow
	{
		_len = 0;
		_processed = -LENGTH_SIZE;
	}

	void fromBuffer(const(ubyte)[] chunk)
	{
		version (DEBUG_BUFFER_BYTES)
		{
			logger.info3!`receiving %u bytes: %(%x %)`(chunk.length, chunk);
		}

		while (chunk.length)
		{
			if (_processed >= 0)
			{
				auto k = min(chunk.length, _len - _processed);

				_buf[_processed .. $][0 .. k] = chunk[0 .. k];
				_processed += k;

				chunk.popFrontN(k);

				if (_processed == _len)
				{
					auto data = _buf[0 .. _len];
					_handler(data);

					onReset;
				}
			}
			else
			{
				bool done = !++_processed;
				_len |= done ? chunk[0] << 8 : chunk[0];

				chunk.popFront;

				if (done)
				{
					_len >= MIN_PACKET && _len <= MAX_PACKET || throwError!`received packet with wrong length %u`(_len);
					_len += VNET_HEADER_SIZE;
				}
			}
		}
	}

private:
	uint _len;
	ubyte[MAX_FRAME] _buf;

	int _processed;
	void delegate(in ubyte[] packet) _handler;
}
