module client.job.write;

import std, utile;
import utile.curl;

import utils, config, app, client, packet;

import client.job;

final class WriterJob : BaseJob
{
	this(TunClient client)
	{
		super(client);
	}

	void add(Blob data)
	{
		if (_s)
		{
			_s.pp.add(data);
			tryWakeup;
		}
	}

	override void check()
	{
		super.check;

		if (_s)
		{
			_s.pp.removeOutdated;
		}
	}

protected:
	override void onCreate(Job e)
	{
		auto p = new S(MAX_CACHED_PACKETS_SIZE);

		e.method = Method.put;
		e.upload;
		e.onRead = &p.dataSend;

		if (_s)
		{
			_s.eof = true;
			tryWakeup; // finish old job
		}

		_s = p;
	}

private:
	void tryWakeup()
	{
		if (_job && _job.paused) // job can be null if there was an error and onComplete was called
		{
			_job.wakeup;
		}
	}

	S* _s;
}

private:

struct S
{
	this(uint sz)
	{
		pp = PacketsWriter(sz);
	}

	uint dataSend(Job, ubyte[] chunk)
	{
		if (uint written = processWrite(chunk))
		{
			return written;
		}

		if (eof)
		{
			return 0;
		}

		return Read.pause;
	}

	uint processWrite(ubyte[] buffer)
	{
		uint total = cast(uint)buffer.length;

		pp.toBuffer(buffer);

		return total - cast(uint)buffer.length;
	}

	bool eof;
	PacketsWriter pp;
}
