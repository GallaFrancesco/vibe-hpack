module HPACK.util;

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
import std.range;
import std.traits;

// decode ubyte as integer representation according to prefix
size_t toInteger(ubyte bbuf, uint prefix) @safe @nogc
{
	assert(prefix < 8, "Prefix must be at most an octet long");

	bbuf = bbuf & ((1 << (8 - prefix)) - 1);
	assert(bbuf >= 0, "Invalid decoded integer");

	return bbuf;
=======
=======
>>>>>>> 53d5b4a... util.d
import std.bitmanip;
=======
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
import std.range;
import std.traits;

// decode ubyte as integer representation according to prefix
size_t toInteger(ubyte bbuf, uint prefix) @safe @nogc
{
	assert(prefix < 8, "Prefix must be at most an octet long");

	bbuf = bbuf & ((1 << (8 - prefix)) - 1);
	assert(bbuf >= 0, "Invalid decoded integer");

<<<<<<< HEAD
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
<<<<<<< HEAD
>>>>>>> 3803d77... moved bitmanip to util.d
=======
>>>>>>> 53d5b4a... util.d
=======
	return bbuf;
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
}
