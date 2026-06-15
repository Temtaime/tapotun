module client;

import std, utile;
import utils, config, app;

import utile.log : logger;

import utile.tun, utile.net, utile.curl;

import client.job;

final class TunClient
{
	this(Requests req, ConfigClient config)
	{
		_req = req;
		_conf = config;

		_reader = new ReaderJob(this);
		_writer = new WriterJob(this);

		_tun = new LinuxTunDevice(_conf.name, logger);
	}

	~this()
	{
		_tun.destroy;
	}

	void fdset(ThreeSet ts)
	{
		if (_needsConfig)
		{
			return;
		}

		ts.add(OpIndex.read, _tun.fd);
	}

	void run()
	{
		_reader.check;
		_writer.check;

		if (_needsConfig)
		{
			return;
		}

		while (true)
		{
			if (auto packet = _tun.read)
			{
				if (packetVersion(packet) == 4)
				{
					_writer.add(packet);
				}
			}
			else
				break;
		}
	}

	@property log() => _tun.log;
package:
	void onPacket(Blob data)
	{
		if (_needsConfig)
		{
			log.error!`received a packet before tun is configured, drop it`;
			return;
		}

		if (packetVersion(data) == PING_PROTO_VERSION)
		{
			_writer.add(data);
		}
		else
			_tun.write(data);
	}

	void configure(Blob data)
	{
		auto sc = data.deserializeMem!ServerConfig;

		_tun.configure(TunSettings(sc.ips[0], sc.prefix, sc.mtu));
		_tun.assignAddress(sc.ips[1 .. $], sc.prefix);

		_needsConfig = false;

		try
		{
			if (_conf.mark)
			{
				_tun.setupFwmark(_conf.mark, _conf.table);
			}

			foreach (r; sc.routes)
			{
				routeAdd(_conf.name, r, log);
			}

			// foreach (r; _conf.routes) // FIXME: force user declared routes ?
			// {
			// 	routeAdd(_conf.name, r, log);
			// }
		}
		catch (Exception e)
		{
			log.error!`failed to setup firewall: %s`(e.msg);
		}
	}

	Requests _req;

	ConfigClient _conf;
	LinuxTunDevice _tun;

	ReaderJob _reader;
	WriterJob _writer;

	bool _needsConfig = true;
}
