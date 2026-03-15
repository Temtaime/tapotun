module web;

import std, utile, utils, config;
import uhttpd;

public import web.client;

class WebServer
{
	this(ushort port)
	{
		_daemon = MHD_start_daemon(
			MHD_USE_ERROR_LOG | MHD_USE_NO_THREAD_SAFETY,
			port,
			null, null,
			&createResponse, this.toVoid,
			MHD_OPTION_CONNECTION_TIMEOUT, CONNECTION_TIMEOUT.toSecs,
			MHD_OPTION_APP_FD_SETSIZE, _FD_SETSIZE,
			MHD_OPTION_NOTIFY_COMPLETED, &completeRequest, this.toVoid,
			MHD_OPTION_END
		);

		_daemon || throwError!`failed to start HTTP daemon on port %u`(port);
	}

	~this()
	{
		MHD_stop_daemon(_daemon);
	}

	void run(ref Selector s)
	{
		MHD_run_from_select(_daemon, s.asPtr!F.expand) || throwError!`failed to run MHD from select`;
	}

	void fdset(ref Selector s)
	{
		MHD_socket maxfd;
		MHD_get_fdset(_daemon, s.asPtr!F.expand, &maxfd) || throwError!`failed to get MHD fdset`;

		s.add(cast(int)maxfd);
	}

	WebClient delegate(void* conn, string url, string method) createClient;
private:
	alias F = uhttpd.fd_set;

	MHD_Daemon* _daemon;
}
