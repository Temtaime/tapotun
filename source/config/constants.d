module config.constants;

import std;

// common
enum NETWORK_BUFFERS = 256 * 1024;
enum MAX_CACHED_PACKETS_SIZE = 12 * 1024 * 1024;

enum PACKET_DELAY = 100.msecs;

alias CONNECTION_RESTART = AliasSeq!(7, 15); // minutes

// server
enum CONNECTION_TIMEOUT = CONNECTION_RESTART[1].minutes + 1.minutes; // must be greater than the max possible connection restart time

// ping
enum CLIENT_PING_COUNT = 8;
enum CLIENT_PING_TOP_COUNT = 6;

enum CLIENT_PING_UNKNOWN = 999.msecs;
enum CLIENT_PING_THRESHOLD = 500.msecs;

enum PING_INTERVAL_SHORT = 10.seconds;
enum PING_INTERVAL_LONG = 55.seconds;

enum CLIENT_PING_PENALTY = 10.minutes;

// client
alias CLIENT_DELAY_ERROR = AliasSeq!(3, 10); // seconds

enum SLOW_SPEED_THRESHOLD = 1; // bytes per second
enum SLOW_SPEED_TIME_WINDOW = 1.minutes;

// app
enum LOOP_DELAY = 1.seconds; // can be greater but keep it low just in case
enum UPDATE_CHECK_INTERVAL = 10.minutes;

enum HEADER_KEY = `x-api-key`;
enum HEADER_TUN = `x-tun-conf`;

// misc
enum DEFAULT_MTU = 1500;
