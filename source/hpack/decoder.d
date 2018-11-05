module hpack.decoder;

import hpack.exception;
import hpack.huffman;
import hpack.tables;
import hpack.util;

import vibe.internal.array : BatchBuffer;

import std.range; // Decoder
import std.string;

/** Module to implement an header decoder consistent with HPACK specifications (RFC 7541)
  * The detailed description of the decoding process, examples and binary format details can
  * be found at:
  * Section 3: https://tools.ietf.org/html/rfc7541#section-3
  * Section 6: https://tools.ietf.org/html/rfc7541#section-6
  * Appendix C: https://tools.ietf.org/html/rfc7541#appendix-C
*/
alias HTTP2SettingValue = uint;

void decode(I, R)(ref I src, ref R dst, ref IndexingTable table) @safe
{
	ubyte bbuf = src[0];
	src = src[1..$];

	if(bbuf & 128) {
		auto res = decodeInteger(src, bbuf);
		dst.put(table[res]);
	} else {
		HTTP2HeaderTableField hres;
		bool update = false;

		if (bbuf & 64) { // inserted in dynamic table
			auto idx = bbuf.toInteger(2);
			if(idx > 0) {  // name == table[index].name, value == literal
				hres.name = table[idx].name;
			} else {   // name == literal, value == literal
				decodeLiteral(src, hres.name);
			}
			decodeLiteral(src, hres.value);
			hres.index = true;
			hres.neverIndex = false;

		} else if(bbuf & 16) { // NEVER inserted in dynamic table
			auto idx = bbuf.toInteger(4);
			if(idx > 0) {  // name == table[index].name, value == literal
				hres.name = table[idx].name;
			} else {   // name == literal, value == literal
				decodeLiteral(src, hres.name);
			}
			decodeLiteral(src, hres.value);
			hres.index = false;
			hres.neverIndex = true;

		} else if(!(bbuf & 32)) { // this occourrence is not inserted in dynamic table
			auto idx = bbuf.toInteger(4);
			if(idx > 0) {  // name == table[index].name, value == literal
				hres.name = table[idx].name;
			} else {   // name == literal, value == literal
				decodeLiteral(src, hres.name);
			}
			decodeLiteral(src, hres.value);
			hres.index = hres.neverIndex = false;

		} else { // dynamic table size update (bbuf[2] is set)
			update = true;
			auto nsize = bbuf.toInteger(3);
			table.updateSize(cast(HTTP2SettingValue)nsize);
		}
		assert(!(hres.index && hres.neverIndex), "Invalid header indexing information");

		if(!update) dst.put(hres);
	}
}

private size_t decodeInteger(I)(ref I src, ubyte bbuf) @safe @nogc
{
	uint nbits = 7;
	auto res = bbuf.toInteger(1);

	if (res < (1 << nbits) - 1) {
		return res;
	} else {
		uint m = 0;
		do {
			// take another octet
			bbuf = src[0];
			src = src[1..$];
			// concatenate it to the result
			res = res + bbuf.toInteger(1)*(1 << m);
			m += 7;
		} while(bbuf == 1);
		return res;
	}
}

private void decodeLiteral(I,R)(ref I src, ref R dst) @safe
{
	ubyte bbuf = src[0];
	src = src[1..$];

	bool huffman = (bbuf & 128) ? true : false;

	auto adst = appender!(immutable(char)[]); // TODO a proper allocator
	assert(!src.empty, "Cannot decode from empty range block");

	// take a buffer of remaining octets
	auto vlen = bbuf.toInteger(1); // value length
	auto buf = src[0..vlen];
	src = src[vlen..$];

	if(huffman) { // huffman encoded
		decodeHuffman(buf, adst);
		dst = adst.data;
	} else { // raw encoded
		dst = cast(string)buf;
	}
}
