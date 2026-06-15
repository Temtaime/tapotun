module utils.fw;

import std, utile, config, utils.net;

void configureFW(string dev)
{
	string table = format!`tapotun_%s`(dev);

	//launch(`nft`, `destroy`, `table`, `inet`, table);

	// create new table and rules
	// launch(`nft`, `table`, `inet`, table);

	// // add masquerade rule for outgoing packets if needed
	// {
	// 	launch(`nft`, `add`, `chain`, `inet`, table, `srcnat`, `{ type nat hook postrouting priority srcnat; }`);

	// 	string rule = format!`oifname %s masquerade`(dev);
	// 	launch(`nft`, `add`, `rule`, `inet`, table, `srcnat`, rule);
	// }
}

/*void configureFirewall(uint mark, Route[] routes)
	{
		string table = format!`tapotun_%s`(_conf.name);

		if (routes.empty)
		{
			return;
		}

		// flush old rules if exist, ignore errors if not exist
		run(`nft`, `table`, `inet`, table);
		run(`nft`, `delete`, `table`, `inet`, table);

		// create new table and rules
		run(`nft`, `table`, `inet`, table);

		// add masquerade rule for outgoing packets if needed
		{
			run(`nft`, `add`, `chain`, `inet`, table, `srcnat`, `{ type nat hook postrouting priority srcnat; }`);

			string rule = format!`oifname %s masquerade`(_conf.name);
			run(`nft`, `add`, `rule`, `inet`, table, `srcnat`, rule);
		}

		// {
		// 	run(`nft`, `add`, `chain`, `inet`, table, `forward`, `{ type filter hook forward priority filter; }`);

		// 	string rule = format!`oifname %s accept`(_conf.name);
		// 	run(`nft`, `add`, `rule`, `inet`, table, `forward`, rule);
		// }
		run(`nft`, `add`, `set`, `inet`, table, `routes`, `{ type ipv4_addr; flags interval; auto-merge; }`);

		foreach (r; routes)
		{
			string route = r.ip.ipToString ~ '/' ~ r.prefix.to!string;

			log.info3!`got a new route %s`(route);

			run(`nft`, `add`, `element`, `inet`, table, `routes`, '{' ~ route ~ '}');
		}

		void add(string type, string hook)
		{
			string rule = format!`{ type %s hook %s priority mangle; }`(type, hook);

			run(`nft`, `add`, `chain`, `inet`, table, hook, rule);

			rule = format!`ip daddr @routes meta mark set %u`(mark);

			run(`nft`, `add`, `rule`, `inet`, table, hook, rule);
		}

		add(`route`, `output`);
		add(`filter`, `prerouting`);
	}*/
