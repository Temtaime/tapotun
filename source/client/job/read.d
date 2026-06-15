module client.job.read;

import std, utile;
import utile.curl;

import utils, config, app, client, packet;

import client.job;

final class ReaderJob : BaseJob
{
	this(TunClient client)
	{
		super(client);
	}

protected:
	override void onCreate(Job e)
	{
		auto s = new S(_client);

		e.method = Method.get;
		e.onHeaders = &onHeaders;
		e.onWrite = &s.dataReceive;
	}

private:
	void onHeaders(Job e)
	{
		if (e.hasError)
		{
			logger.error!`error receiving tun configuration, code %u`(e.code);
			return;
		}

		with (_client)
		{
			if (auto p = HEADER_TUN in e.responseHeaders)
			{
				configure(Base64.decode(*p));
			}
			else
			{
				logger.fatal!`missing tun configuration header in response`;
			}
		}
	}
}

private:

struct S
{
	this(TunClient client)
	{
		pp = PacketsReader(&client.onPacket);
	}

	uint dataReceive(Job e, ubyte[] chunk)
	{
		if (e.hasError) // code is not 200
		{
			return Write.abort;
		}

		try
		{
			pp.fromBuffer(chunk);
			return cast(uint)chunk.length;
		}
		catch (Exception e)
		{
			logger.error!`error processing received data: %s`(e.msg);
		}

		return Write.abort;
	}

	PacketsReader pp;
}
