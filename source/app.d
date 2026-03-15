import std, core.thread, core.memory, utile;
import tun, utils, web, curl, utils, config, client, server;

__gshared App myApp;

class App
{
	this(string config)
	{
		logger.info!`VPN application starting ...`;

		_config = config;
		_req = new Requests;
	}

	~this()
	{
		_clients.each!(a => a.destroy);
		_servers.each!(a => a.destroy);

		_req.destroy;
	}

	void run()
	{
		while (_run)
		{
			// update app time
			appTime.update;

			// process interfaces
			work;

			// process curl jobs
			_req.run;
		}
	}

private:
	void work()
	{
		if (_config.empty)
		{
			loop;
		}
		else
		{
			configure;
		}
	}

	void configure()
	{
		foreach (t; _config.parseConfig)
		{
			if (t.port)
			{
				_servers ~= new TunServer(t);
			}
			else
			{
				_clients ~= new TunClient(_req, t);
			}
		}

		_config = null;
	}

	void loop()
	{
		// process network events
		Selector s;

		{
			_req.fdset(s); // FIXME: check if we need to move it outside the loop

			_clients.each!(a => a.fdset(s));
			_servers.each!(a => a.fdset(s));

			s.do_(LOOP_DELAY);
		}

		// process TUN clients
		_clients.each!(a => a.run);

		// process TUN server
		_servers.each!(a => a.run(s));
	}

	void onUpdate()
	{
		_run = false;
		logger.info!`application updated, shutting down ...`;
	}

	Requests _req;

	TunClient[] _clients;
	TunServer[] _servers;

	bool _run = true;
	string _config;
}

void main(string[] args)
{
	logger.timeOutput = true;

	if (args.length != 2)
	{
		return logger.error!`usage: %s <config file>`(args.front);
	}

	auto config = args.back;

	if (config.isFile)
	{
		myApp = new App(config);
		myApp.run;
		myApp.destroy;
	}
	else
	{
		logger.error!`%s is not a file`(config);
	}
}
