module HPACK.encoder;

import HPACK.tables;
import HPACK.huffman;
import HPACK.util;
import HPACK.exception;

import vibe.http.status;
import vibe.http.common;

import std.range;
import std.bitmanip; // prefix encoding / decoding
import std.typecons;
import std.conv;
import std.exception;
import std.array;

struct HeaderEncoder(T = HTTP2HeaderTableField[])
	if(isInputRange!T &&
	is(ElementType!T : HTTP2HeaderTableField))
{
	private {
		T m_range;
		IndexingTable m_table;
		ubyte[] m_encoded;
	}

	bool huffman;

	this(T range, IndexingTable table, bool huff = true) @trusted
	{
		m_range = range;
		m_table = table;
		huffman = huff;

		encode();
	}

// InputRange specific methods
	@property bool empty() @safe { return m_encoded.empty; }

	@property ubyte[] front() @safe { return m_encoded; }

	@property ubyte[] back() @safe { return m_encoded; }

	void popFront() @trusted
	{
		enforce!HPACKException(!empty, "Cannot call popFront on an empty HeaderDecoder");

		m_encoded.popFront();

		// advance if data is still available
		if(!m_range.empty) encode();
	}

	void put(T)(T range) @safe
		if(is(ElementType!T : HTTP2HeaderTableField))
	{
		m_range.put(range);

		encode();
	}

	private {
		void encode() @trusted
		{
			// pop a header
			auto header = m_range[0];
			m_range = m_range[1..$];

			// try to encode as integer
			bool indexed = encodeInteger(header);
			if(!indexed) encodeLiteral(header);
		}

		bool encodeInteger(const HTTP2HeaderTableField header) @safe
		{
			// check table for indexed headers
			size_t idx = 1;
			auto bbuf = appender!(ubyte[]); // TODO a proper allocator
			while(idx < m_table.size) {
				// encode both name / value as index
				auto h = m_table[idx];
				if(h.name == header.name && h.value == header.value) {
					if(idx < 127) { // can be fit in one octet
						bbuf.put(cast(ubyte)(idx ^ 128));
					} else { 		// must be split in multiple octets
						bbuf.put(cast(ubyte)255);
						idx -= 127;
						while (idx > 127) {
							bbuf.put(cast(ubyte)((idx % 128) ^ 128));
							idx = idx / 128;
						}
						bbuf.put(cast(ubyte)(idx & 127));
					}
					m_encoded = bbuf.data;
					return true;

				// encode name as index, value as literal
				} else if(h.name == header.name && h.value != header.value) {
					// encode name as index ( always smaller than 64 )
					bbuf.put(cast(ubyte)((idx + 64) & 127));
					// encode value as literal
					if(huffman) {
						auto hbuf = appender!(ubyte[]); // TODO a proper allocator
						auto len = encodeHuffman(to!string(header.value), hbuf);
						bbuf.put(cast(ubyte)((len/8 ^ 128) + 1));
						bbuf.put(hbuf.data);
					} else {
						auto blen = (header.value.length) & 127;
						bbuf.put(cast(ubyte)blen);
						bbuf.put(cast(ubyte[])(to!string(header.value).dup));
					}
					m_encoded = bbuf.data;
					return true;

				}
				idx++;
			}
			return false;
		}

		void encodeLiteral(const HTTP2HeaderTableField header) @safe {
			assert(false);
		}
	}
}

unittest {
	// Following examples can be found in Appendix C of the HPACK RFC
	import HPACK.decoder;
	IndexingTable table;
	/** 1. Literal header field w. indexing (raw)
	  * custom-key: custom-header
	  */
	// TODO encodeLiteral
	//HTTP2HeaderTableField[] h1 = [HTTP2HeaderTableField("custom-key", "custom-header")];
	//auto e1 = HeaderEncoder!(HTTP2HeaderTableField[])(h1, table);
	//auto d1 = HeaderDecoder!(ubyte[])(e1.front, table);
	//assert(d1.front == h1.front);

	/** 1bis. Literal header field w. indexing (huffman encoded)
	  * :authority: www.example.com
	  */
	HTTP2HeaderTableField[] h1b = [HTTP2HeaderTableField(":authority", "www.example.com")];
	auto e1b = HeaderEncoder!(HTTP2HeaderTableField[])(h1b, table);
	auto d1b = HeaderDecoder!(ubyte[])(e1b.front, table);
	assert(d1b.front == h1b.front);

	/** 2. Literal header field without indexing (raw)
	  * :path: /sample/path
	  */
	HTTP2HeaderTableField[] h2 = [HTTP2HeaderTableField(":path", "/sample/path")];
	// initialize with huffman=false (can be modified by e2.huffman)
	auto e2 = HeaderEncoder!(HTTP2HeaderTableField[])(h2, table, false);
	auto d2 = HeaderDecoder!(ubyte[])(e2.front, table);
	assert(d2.front == h2.front);

	/** 3. Literal header field never indexed (raw)
	  * password: secret
	  */
	// TODO encodeLiteral
	//HTTP2HeaderTableField[] h3 = [HTTP2HeaderTableField("password", "secret")];
	//auto e3 = HeaderEncoder!(HTTP2HeaderTableField[])(h3, table, false);
	//auto d3 = HeaderDecoder!(ubyte[])(e3.front, table);
	//assert(d3.front == h3.front);

	/** 4. Indexed header field (integer) 
	  * :method: GET
	  */
	HTTP2HeaderTableField[] h4 = [HTTP2HeaderTableField(":method", HTTPMethod.GET)];
	auto e4 = HeaderEncoder!(HTTP2HeaderTableField[])(h4, table);
	auto d4 = HeaderDecoder!(ubyte[])(e4.front, table);
	assert(d4.front == h4.front);

}
