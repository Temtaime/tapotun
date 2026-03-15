module utils.time;

import std, utile;

__gshared AppTime appTime;

shared static this()
{
	with (appTime)
	{
		_ms = 1; // ensure ms is not zero at startup
		_start = now - _ms;
	}
}

struct AppTime
{
	void update()
	{
		_ms = cast(uint)(now - _start);
	}

private:
	mixin publicProperty!(uint, `ms`);

	static now() => Clock.currStdTime.convert!(`hnsecs`, `msecs`);

	ulong _start;
}

int toMsecs(Duration d) => cast(int)d.total!`msecs`;
int toSecs(Duration d) => cast(int)d.total!`seconds`;

struct AppTimer
{
	@disable this();

	this(Duration delay)
	{
		_start = appTime.ms;
		_delay = delay.toMsecs;
	}

	bool peek() => appTime.ms - _start >= _delay;

	bool isFired()
	{
		if (peek)
		{
			_start = appTime.ms;
			return true;
		}

		return false;
	}

	void reset()
	{
		_start = appTime.ms;
	}

private:
	uint _start;
	uint _delay;
}

struct TimerFunc
{
	@disable this();

	this(Duration delay, void delegate() func, bool once)
	{
		_start = appTime.ms;
		_delay = delay.toMsecs;
		_func = func;
		_once = once;
	}

	void check()
	{
		if (_func && appTime.ms - _start >= _delay)
		{
			_func();

			if (_once)
			{
				_func = null;
			}
			else
				_start = appTime.ms;
		}
	}

private:
	uint _start;
	uint _delay;
	void delegate() _func;
	bool _once;
}

struct AppTimeMeter
{
	static init() => AppTimeMeter(appTime.ms);

	auto elapsed() => msecs(appTime.ms - _start);
private:
	uint _start;
}
