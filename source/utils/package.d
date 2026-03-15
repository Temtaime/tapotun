module utils;
import std, utile, core.memory, core.sys.posix.arpa.inet, core.thread;

public import utils.mem;
public import utils.net;
public import utils.time;

import config, packet;

//version = DEBUG_PING;

uint ping(ref AppTimer p, ubyte[] chunk)
{
	if (p.isFired)
	{
		if (chunk.length >= LENGTH_SIZE)
		{
			version (DEBUG_PING)
			{
				logger.info3!`sending ping`;
			}

			chunk[0 .. LENGTH_SIZE] = 0;
			return LENGTH_SIZE;
		}

		logger.warn!`ping skipped, buffer too small`; // FIXME: should not happen
	}

	return 0;
}

void pong()
{
	version (DEBUG_PING)
	{
		logger.info3!`pong received`;
	}
}
