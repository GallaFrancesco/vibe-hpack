module hpack.encoder;

import hpack.tables;
import hpack.huffman;
import hpack.util;

import std.typecons;
import std.conv;
import std.array;

void encode(R)(HTTP2HeaderTableField header, ref R dst, ref IndexingTable table, bool huffman = true) @safe
{
	// try to encode as integer
	bool indexed = encodeInteger(header, dst, table, huffman);
	// if fail, encode as literal
	if(!indexed) encodeLiteral(header, dst, huffman);
}

/// encode a pure integer (present in table) or integer name + literal value
private bool encodeInteger(R)(const HTTP2HeaderTableField header, ref R dst, ref IndexingTable table, bool huffman) @safe
{
	// check table for indexed headers
	size_t idx = 1;
	bool found = false;
	size_t partialFound = false;

	while(idx < table.size) {
		// encode both name / value as index
		auto h = table[idx];
		if(h.name == header.name && h.value == header.value) {
			found = true;
			partialFound = false;
			break;
			// encode name as index, value as literal
		} else if(h.name == header.name && h.value != header.value) {
			found = false;
			partialFound = idx;
		}
		idx++;
	}

	if(found) {
		if(idx < 127) { // can be fit in one octet
			dst.put(cast(ubyte)(idx ^ 128));
		} else { 		// must be split in multiple octets
			dst.put(cast(ubyte)255);
			idx -= 127;
			while (idx > 127) {
				dst.put(cast(ubyte)((idx % 128) ^ 128));
				idx = idx / 128;
			}
			dst.put(cast(ubyte)(idx & 127));
		}
		return true;

	} else if(partialFound) {
		// encode name as index ( always smaller than 64 )
		if(header.index) dst.put(cast(ubyte)((partialFound + 64) & 127));
		else if (header.neverIndex) dst.put(cast(ubyte)((partialFound + 16) & 31));
		else dst.put(cast(ubyte)(partialFound & 15));
		// encode value as literal
		encodeLiteralField(to!string(header.value), dst, huffman);

		return true;
	}

	return false;
}

/// encode a literal field depending on its indexing requirements
private void encodeLiteral(R)(const HTTP2HeaderTableField header, ref R dst, bool huffman) @safe
{
	if(header.index) dst.put(cast(ubyte)(64));
	else if(header.neverIndex) dst.put(cast(ubyte)(16));
	else dst.put(cast(ubyte)(0));

	encodeLiteralField(to!string(header.name), dst, huffman);
	encodeLiteralField(to!string(header.value), dst, huffman);
}

/// encode a field (name / value) using huffman or raw encoding
private void encodeLiteralField(R)(string src, ref R dst, bool huffman) @safe
{
	if(huffman) {
		auto hbuf = appender!(ubyte[]); // TODO a proper allocator
		auto len = encodeHuffman(src, hbuf);
		dst.put(cast(ubyte)((len/8 ^ 128) + 1));
		dst.put(hbuf.data);
	} else {
		auto blen = (src.length) & 127;
		dst.put(cast(ubyte)blen);
		dst.put(cast(ubyte[])(to!string(src).dup));
	}
}
