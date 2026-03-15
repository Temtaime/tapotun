module client;

import std, utile;
import tun, utils, tun.linux, curl, config, web, app;

import client.job;

class TunClient
{
	this(Requests req, TunConfig config)
	{
		_req = req;
		_conf = config;

		_reader = new ReaderJob(this);
		_writer = new WriterJob(this);

		logger.info!`connecting to %s`(_conf.server);
	}

	~this()
	{
		if (_tun)
		{
			_tun.destroy;
		}
	}

	void fdset(ref Selector s)
	{
		if (_tun)
		{
			FD_SET(_tun.fd, s.read);
			s.add(_tun.fd);
		}
	}

	void run()
	{
		_reader.check;
		_writer.check;

		if (_tun is null)
			return;

		while (true)
		{
			if (auto data = _tun.read)
			{
				_writer.add(data);
			}
			else
				break;
		}
	}

package:
	void onPacket(in ubyte[] data)
	{
		assert(_configured);

		if (data.empty) // ping
		{
			pong;
		}
		else
			_tun.write(data);
	}

	void configure(in ubyte[] data)
	{
		auto sc = data.deserializeMem!ServerConfig;

		if (_tun is null)
		{
			_tun = new TunDevice(_conf.name);
		}

		_tun.configure(Settings(sc.ip, sc.prefix, sc.mtu));
		_configured = true;

		if (_conf.mark.value)
		{
			setupFwmark(_conf.name, _conf.mark.value, _conf.mark.table);
		}
	}

	Requests _req;
	TunConfig _conf;

	TunDevice _tun;
	bool _configured;

	ReaderJob _reader;
	WriterJob _writer;
}
