module packet;

import std, utile, web, tun, app, utils.time, config;

import std.experimental.allocator.gc_allocator;
import std.experimental.allocator.building_blocks.kernighan_ritchie;

//version = DEBUG_BUFFER_BYTES;

enum ubyte LENGTH_SIZE = ushort.sizeof;

public import packet.writer;
public import packet.reader;
