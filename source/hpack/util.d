module HPACK.util;

import std.bitmanip;
import std.range;
import std.traits;

// decode byte (BitArray[8]) as integer representation
size_t toInteger(BitArray bbuf, uint prefix) @trusted
{
	assert(prefix < bbuf.length, "Prefix must be at most an octet long");
	for(uint i=0; i<prefix; ++i) bbuf[i] = 0;

	size_t res = 0;
	foreach(b; bbuf.bitsSet) {
		res |= 1 << (7 - b);
	}
	return res;
}

// convert ubyte to BitArray representation (nbits == arraylen*8)
BitArray toBitArray(T)(T data) @trusted
if(is(ElementType!T : const(ubyte)) || is(ElementType!T : const(char)) || isIntegral!T)
{
	BitArray bdata;
	static if(isIntegral!T) {
		// int to BitArray
		bdata = BitArray(cast(void[])[data], 8);
	} else {
		// char[], ubyte[], bool[] to BitArray
		bdata = BitArray(cast(void[])data, data.length*8);
	}
	return bdata.reverse;
}
