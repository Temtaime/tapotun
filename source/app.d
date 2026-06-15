import std, core.thread, core.memory, utile;
import utile.tun, utils, utils, config, utile.updater, client, server, update;

import utile.net, utile.curl;

final class App
{
	this(Requests req)
	{
		_req = req;
	}

	~this()
	{
		_clients.each!(a => a.destroy);
		_servers.each!(a => a.destroy);
	}

	int run(string[] args)
	{
		if (args.length != 2)
		{
			logger.error!`usage: %s <config file>`(args.front);
		}
		else
		{
			auto config = args.back;

			if (config.isFile)
			{
				configure(config);
				loop;
				return 0;
			}
			else
			{
				logger.error!`%s is not a file`(config);
			}
		}

		return 1;
	}

	void stop()
	{
		_run = false;
	}

private:
	void onNewJob(Job job)
	{
		job.impersonate(Browser.safari260_ios, false);
		job.lowSpeed(SLOW_SPEED_THRESHOLD, SLOW_SPEED_TIME_WINDOW);

		// use one connection for up/down to avoid issues
		job.version_ = Alpn.v1_1_only;
	}

	void configure(string config)
	{
		_req.onNewJob = &onNewJob; // impersonate all requests
		//_req.maxConcurrentStreams = 1; // use a single connection for up/down

		foreach (t; config.parseConfig)
		{
			if (auto p = cast(ConfigServer)t)
			{
				_servers ~= new TunServer(p);
			}
			else
			{
				_clients ~= new TunClient(_req, cast(ConfigClient)t);
			}
		}
	}

	void loop()
	{
		for (ThreeSet ts = new ThreeSet; _run; appTime.update)
		{
			// check for updates every UPDATE_CHECK_INTERVAL
			checkUpdates;

			// reset fd sets
			ts.reset;

			// add fds
			_clients.each!(a => a.fdset(ts));
			_servers.each!(a => a.fdset(ts));
			_req.fdset(ts);

			// wait for events
			ts.select(LOOP_DELAY);

			// process tun events
			_clients.each!(a => a.run);
			_servers.each!(a => a.run(ts));

			// process curl events
			_req.run;
		}
	}

	Requests _req;

	TunClient[] _clients;
	TunServer[] _servers;

	bool _run = true;
}

int main(string[] args)
{
	logger.timeOutput = true;

	scope req = new Requests(logger);
	scope app = new App(req);

	return updateAvailable(req, &app.stop) ? 0 : app.run(args);
}
