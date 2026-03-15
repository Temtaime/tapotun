module client.job;

import std, utile;
import tun, utils, curl, config, web, app, client, packet;

version = LOG_CLIENT_JOBS;

abstract class BaseJob
{
	this(TunClient client)
	{
		_client = client;
		_tm = TimerFunc(Duration.init, &onCreate, true);
	}

	void check() => _tm.check;
protected:

	Job makeJob()
	{
		_meter = AppTimeMeter.init;

		with (_client)
		{
			auto job = _req.makeJob(_conf.server);

			job.header(HEADER_KEY, _conf.token);

			job.buffers = NETWORK_BUFFERS;
			job.method = _method;
			job.version_ = Alpn.v1_1_only;
			job.onComplete = &onComplete;

			version (LOG_CLIENT_JOBS)
			{
				logger.info!`created %s job to %s`(_method, _conf.server);
			}

			return job;
		}
	}

	abstract void onCreate();

	void onComplete(Job job)
	{
		if (job.isError)
		{
			logger.warn!`%s job failed, code %d, elapsed %s`(_method, job.code, _meter.elapsed);
		}
		else version (LOG_CLIENT_JOBS)
		{
			logger.info!`%s job completed, code %d, elapsed %s`(_method, job.code, _meter.elapsed);
		}

		if (job.isError)
		{
			auto delay = uniform(CLIENT_DELAY_ERROR_MIN, CLIENT_DELAY_ERROR_MAX).seconds;

			_tm = TimerFunc(delay, &onCreate, true);
		}
		else
			onCreate;
	}

	string _method;
	TunClient _client;
private:
	TimerFunc _tm;
	AppTimeMeter _meter;
}

final:

class ReaderJob : BaseJob
{
	this(TunClient client)
	{
		super(client);

		_method = Method.get;
		_pp = PacketsReader(&_client.onPacket);
	}

protected:
	override void onCreate()
	{
		auto job = makeJob;

		job.onWrite = &dataReceive;
		job.onHeaders = &onHeaders;

		with (_client)
		{
			_configured = false;
		}
	}

private:
	void onHeaders(Job job)
	{
		if (job.isError)
			return;

		with (_client)
		{
			string s = job.responseHeaders.get(HEADER_TUN, null);
			s.length || throwError!`missing tun configuration header`;

			configure(Base64.decode(s));
		}
	}

	uint dataReceive(Job job, ubyte[] chunk)
	{
		if (job.isError)
		{
			return Write.abort;
		}

		try
		{
			_pp.fromBuffer(chunk);
			return cast(uint)chunk.length;
		}
		catch (Exception e)
		{
			logger.error!`error processing received data: %s`(e.msg);
		}

		return Write.abort;
	}

	PacketsReader _pp;
}

class WriterJob : BaseJob
{
	this(TunClient client)
	{
		super(client);

		_method = Method.put;
		_pp = PacketsWriter(MAX_CACHED_PACKETS_SIZE);
		_ping = AppTimer(PING_INTERVAL);
	}

	void add(in ubyte[] data)
	{
		_pp.add(data);
		tryWakeup;
	}

	override void check()
	{
		super.check;
		_pp.removeOutdated;

		if (_ping.peek)
		{
			tryWakeup;
		}
	}

protected:
	override void onCreate()
	{
		with (_client)
		{
			_job = makeJob;
			_job.upload;
			_job.onRead = (j, data) => dataSend(data);
		}

		_timeout = makeTimeout;
	}

	override void onComplete(Job job)
	{
		_job = null;
		super.onComplete(job);
	}

private:
	void tryWakeup()
	{
		if (_job && _job.paused)
		{
			_job.wakeup;
		}
	}

	uint dataSend(ubyte[] chunk)
	{
		if (uint written = processWrite(chunk))
		{
			_ping.reset;
			return written;
		}

		if (uint written = ping(_ping, chunk))
		{
			return written;
		}

		if (_meter.elapsed >= _timeout)
		{
			logger.info!`restarting writer job due to connection timeout %s`(_timeout);
			return 0;
		}

		return Read.pause;
	}

	uint processWrite(ubyte[] buffer)
	{
		uint total = cast(uint)buffer.length;

		_pp.toBuffer(buffer);

		return total - cast(uint)buffer.length;
	}

	Job _job;
	PacketsWriter _pp;

	AppTimer _ping;
	Duration _timeout;
}
