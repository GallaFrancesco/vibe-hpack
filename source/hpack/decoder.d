module HPACK.decoder;

import HPACK.exception;
import HPACK.huffman;
import HPACK.tables;
import HPACK.util;

import std.range; // Decoder
import std.string : representation;

/** Module to implement an header decoder consistent with HPACK specifications (RFC 7541)
  * The detailed description of the decoding process, examples and binary format details can
  * be found at:
  * Section 3: https://tools.ietf.org/html/rfc7541#section-3
  * Section 6: https://tools.ietf.org/html/rfc7541#section-6
  * Appendix C: https://tools.ietf.org/html/rfc7541#appendix-C
*/
alias HTTP2SettingValue = uint;

/** implements an input range to decode an header block
  * m_table is a reference to the original table
  */
struct HeaderDecoder(T = ubyte[])
		if (isInputRange!T && (is(ElementType!T : char) || (is(ElementType!T : ubyte))))
{
	private {
		immutable(ubyte)[] m_range;
		IndexingTable m_table; // only for retrieving data
		HTTP2HeaderTableField m_decoded;
		HTTP2HeaderTableField[] m_index; // to be appended
		HTTP2HeaderTableField[] m_noindex;
	}

	this(T range, IndexingTable table) @trusted
	{
		//static if(is(ElementType!T : char)) m_range = cast(ubyte[])range;
		static if(is(typeof(representation(range)) == immutable(ubyte)[])) m_range = range;
		else m_range = cast(immutable(ubyte)[])range;

		m_table = table;

		decode();
	}

// InputRange specific methods
	@property bool empty() @safe @nogc { return m_range.empty; }

	@property HTTP2HeaderTableField front() @safe @nogc { return m_decoded; }

	void popFront() @safe
	{
		assert(!empty, "Cannot call popFront on an empty HeaderDecoder");

		// advance if data is still available
		decode();
	}

	void put(T)(T range) @trusted
	{
		static if(is(typeof(representation(range)) == immutable(ubyte)[])) m_range = range;
		else m_range ~= cast(immutable(ubyte)[])range;

		decode();
	}

	@property HTTP2HeaderTableField[] toIndex() @safe @nogc { return m_index; }

	@property HTTP2HeaderTableField[] neverIndexed() @safe @nogc { return m_noindex; }

// decoding
	private {

		void decode() @safe
		{
			ubyte bbuf = m_range[0];
			m_range = m_range[1..$];

			if(bbuf & 128) {
				auto res = decodeInteger(bbuf);
				m_decoded = m_table[res];
			} else {
				HTTP2HeaderTableField hres;
				bool update = false;

				if (bbuf & 64) { // inserted in dynamic table
					auto idx = bbuf.toInteger(2);
					if(idx > 0) {  // name == table[index].name, value == literal
						hres.name = m_table[idx].name;
					} else {   // name == literal, value == literal
						hres.name = decodeLiteral();
					}
					hres.value = decodeLiteral();
					m_index ~= hres;

				} else if(bbuf & 16) { // NEVER inserted in dynamic table
					auto idx = bbuf.toInteger(4);
					if(idx > 0) {  // name == table[index].name, value == literal
						hres.name = m_table[idx].name;
					} else {   // name == literal, value == literal
						hres.name = decodeLiteral();
					}
					hres.value = decodeLiteral();
					m_noindex ~= hres;

				} else if(!(bbuf & 32)) { // this occourrence is not inserted in dynamic table
					auto idx = bbuf.toInteger(4);
					if(idx > 0) {  // name == table[index].name, value == literal
						hres.name = m_table[idx].name;
					} else {   // name == literal, value == literal
						hres.name = decodeLiteral();
					}
					hres.value = decodeLiteral();

				} else { // dynamic table size update (bbuf[2] is set)
					update = true;
					auto nsize = bbuf.toInteger(3);
					m_table.updateSize(cast(HTTP2SettingValue)nsize);
				}

				if(!update) m_decoded = hres;
			}
		}

		size_t decodeInteger(ubyte bbuf) @safe @nogc
		{
			uint nbits = 7;
			auto res = bbuf.toInteger(1);

			if (res < (1 << nbits) - 1) {
				return res;
			} else {
				uint m = 0;
				do {
					// take another octet
					bbuf = m_range[0];
					m_range = m_range[1..$];
					// concatenate it to the result
					res = res + bbuf.toInteger(1)*(1 << m);
					m += 7;
				} while(bbuf == 1);
				return res;
			}
		}

		string decodeLiteral() @safe
		{
			ubyte bbuf = m_range[0];
			m_range = m_range[1..$];

			string res;
			bool huffman = (bbuf & 128) ? true : false;


			assert(!m_range.empty, "Cannot decode from empty range block");

			// take a buffer of remaining octets
			auto vlen = bbuf.toInteger(1); // value length
			auto buf = m_range[0..vlen];
			m_range = m_range[vlen..$];

			if(huffman) { // huffman encoded
				res = decodeHuffman(buf);
			} else { // raw encoded
				res = cast(string)(buf);
			}
			return res;
		}
	}
}

unittest {
	// Following examples can be found in Appendix C of the HPACK RFC

	IndexingTable table = IndexingTable(4096);
	/** 1. Literal header field w. indexing (raw)
	  * custom-key: custom-header
	  */
	ubyte[] block = [0x40, 0x0a, 0x63, 0x75, 0x73, 0x74, 0x6f, 0x6d, 0x2d, 0x6b, 0x65, 0x79,
		0x0d, 0x63, 0x75, 0x73, 0x74, 0x6f, 0x6d, 0x2d, 0x68, 0x65, 0x61, 0x64, 0x65, 0x72];

	auto decoder = HeaderDecoder!(ubyte[])(block, table);
	assert(decoder.front.name == "custom-key" && decoder.front.value == "custom-header");
	// check entries to be inserted in the indexing table (dynamic)
	assert(decoder.toIndex.front.name == "custom-key" && decoder.toIndex.front.value == "custom-header");

	/** 1bis. Literal header field w. indexing (huffman encoded)
	  * :authority: www.example.com
	  */
	block = [0x41, 0x8c, 0xf1, 0xe3, 0xc2, 0xe5, 0xf2, 0x3a, 0x6b, 0xa0, 0xab, 0x90, 0xf4, 0xff];
	decoder.put(block);
	assert(decoder.front.name == ":authority" && decoder.front.value == "www.example.com");
	assert(decoder.toIndex.back.name == ":authority" && decoder.toIndex.back.value == "www.example.com");

	/** 2. Literal header field without indexing (raw)
	  * :path: /sample/path
	  */
	block = [0x04, 0x0c, 0x2f, 0x73, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0x2f, 0x70, 0x61, 0x74, 0x68];
	decoder.put(block);
	assert(decoder.front.name == ":path" && decoder.front.value == "/sample/path");


	/** 3. Literal header field never indexed (raw)
	  * password: secret
	  */
	block = [0x10, 0x08, 0x70, 0x61, 0x73, 0x73, 0x77, 0x6f, 0x72, 0x64, 0x06, 0x73, 0x65,
		  0x63, 0x72, 0x65, 0x74];
	decoder.put(block);
	assert(decoder.front.name == "password" && decoder.front.value == "secret");
	assert(decoder.neverIndexed.back.name == "password" && decoder.neverIndexed.back.value == "secret");


	/** 4. Indexed header field (integer)
	  * :method: GET
	  */
	import vibe.http.common;
	block = [0x82];
	decoder.put(block);
	assert(decoder.front.name == ":method" && decoder.front.value == HTTPMethod.GET);

	/** 5. Full request without huffman encoding
	  * :method: GET
      * :scheme: http
      * :path: /
      * :authority: www.example.com
      * cache-control: no-cache
	  */
	block = [0x82, 0x86, 0x84, 0xbe, 0x58, 0x08, 0x6e, 0x6f, 0x2d, 0x63, 0x61, 0x63, 0x68, 0x65];
	table.insert(HTTP2HeaderTableField(":authority", "www.example.com"));
	auto rdec = HeaderDecoder!(ubyte[])(block, table);
	HTTP2HeaderTableField[] expected = [
		HTTP2HeaderTableField(":method", HTTPMethod.GET),
		HTTP2HeaderTableField(":scheme", "http"),
		HTTP2HeaderTableField(":path", "/"),
		HTTP2HeaderTableField(":authority", "www.example.com"),
		HTTP2HeaderTableField("cache-control", "no-cache")];

	foreach(i,h; rdec.enumerate(0)) {
		assert(h == expected[i]);
	}

	/** 5. Full request with huffman encoding
	  * :method: GET
      * :scheme: http
      * :path: /
      * :authority: www.example.com
      * cache-control: no-cache
	  */
	block = [0x82, 0x86, 0x84, 0xbe, 0x58, 0x86, 0xa8, 0xeb, 0x10, 0x64, 0x9c,0xbf];
	auto hdec = HeaderDecoder!(ubyte[])(block, table);

	foreach(i,h; hdec.enumerate(0)) {
		assert(h == expected[i]);
	}
}
