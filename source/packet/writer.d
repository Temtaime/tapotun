module packet.writer;

import packet;
import std, utile, web, tun, app, utils.time, config;

import std.experimental.allocator.gc_allocator;
import std.experimental.allocator.building_blocks.kernighan_ritchie;

struct PacketsWriter
{
	@disable this();

	this(uint capacity)
	{
		onReset;

		_alloc = KRRegion!GCAllocator(capacity);
		_alloc.switchToFreeList;
	}

	void onReset()
	{
		_processed = -LENGTH_SIZE;
	}

	void removeOutdated()
	{
		if (_head is null)
			return;

		uint removed, total;

		while (true)
		{
			auto p = _head.next;

			if (p is null || appTime.ms - p.time < PACKET_DELAY)
			{
				break;
			}

			removed++;
			total += p.size;

			auto next = p.next;
			free(p);
			_head.next = next;

			if (next is null)
			{
				_tail = _head;
				break;
			}
		}

		if (removed)
		{
			logger.dbg!`removed %u outdated packets, total %u bytes`(removed, total);
		}
	}

	void add(in ubyte[] packet)
	{
		auto sz = cast(uint)packet.length;

		sz >= MIN_FRAME && sz <= MAX_FRAME || throwError!`trying to send packet with wrong length %u`(sz);

		auto tmp = _alloc
			.allocate(sz + S.sizeof)
			.toByte;

		if (tmp is null)
		{
			logger.error!`packet writer OOM, allocated %u packets, %u bytes`(_count, _size);
			return;
		}

		_count++;
		_size += sz;

		auto p = cast(S*)tmp.ptr;

		p.size = sz;
		p.time = appTime.ms;
		p.next = null;

		data(p)[] = packet;

		if (_head)
		{
			_tail.next = p;
		}
		else
			_head = p;

		_tail = p;
	}

	void toBuffer(ref ubyte[] buffer)
	{
		while (buffer.length && _head)
		{
			auto data = data(_head);

			version (DEBUG_BUFFER_BYTES)
			{
				logger.info2!`packet length: %u, processed: %d`(_head.size, _processed);
			}

			if (_processed >= 0)
			{
				auto k = min(_head.size - _processed, buffer.length);

				auto tmp = buffer[0 .. k];
				tmp[] = data[_processed .. $][0 .. k];

				version (DEBUG_BUFFER_BYTES)
				{
					logger.info3!`sending %u bytes: %(%x %)`(k, tmp);
				}

				_processed += k;
				buffer.popFrontN(k);

				if (_processed == _head.size)
				{
					onReset;
					removeFront;
				}
			}
			else
			{
				uint len = _head.size - VNET_HEADER_SIZE;

				buffer[0] = len.toByte[_processed + LENGTH_SIZE];

				version (DEBUG_BUFFER_BYTES)
				{
					auto tmp = buffer[0 .. 1];
					logger.info3!`sending %u bytes: %(%x %)`(tmp.length, tmp);
				}

				_processed++;
				buffer.popFront;
			}
		}
	}

private:
	struct S
	{
		uint size;
		uint time;
		S* next;
	}

	static assert(S.sizeof == 16);

	auto data(S* p) => (cast(ubyte*)(p + 1))[0 .. p.size];
	auto block(S* p) => (cast(ubyte*)p)[0 .. p.size + S.sizeof];

	void free(S* p)
	{
		_count--;
		_size -= p.size;

		auto res = _alloc.deallocate(block(p));
		assert(res);
	}

	void removeFront()
	{
		auto p = _head.next;
		free(_head);
		_head = p;
	}

	S* _head;
	S* _tail;

	uint _size;
	uint _count;

	int _processed;
	KRRegion!GCAllocator _alloc;
}
