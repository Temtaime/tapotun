module client.job;

import std, utile;
import utile.curl;

import utils, config, app, client, packet;

public import client.job.read;
public import client.job.write;

package:

abstract class BaseJob
{
	this(TunClient client)
	{
		_client = client;
	}

	void check()
	{
		if (_next >= appTime.now)
			return;

		createJob;
		_next = appTime.now + uniform(CONNECTION_RESTART).minutes;
	}

protected:
	abstract void onCreate(Job);

	Job _job;
	TunClient _client;
private:
	void createJob()
	{
		with (_client)
		{
			auto e = _req.create(_conf.server);

			e.header(HEADER_KEY, _conf.token);
			e.buffers = NETWORK_BUFFERS;

			e.onComplete = &onComplete;
			onCreate(e);

			_job = e;
		}
	}

	void onComplete(Job e)
	{
		if (_job is e)
		{
			if (_job.hasError)
			{
				_next = appTime.now + errorDelay;
			}

			_job = null;
		}
	}

	static errorDelay() => uniform(CLIENT_DELAY_ERROR).seconds;

	MonoTime _next;
}
