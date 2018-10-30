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
	if(isInputRange!T && is(ElementType!T : HTTP2HeaderTableField) ||
	   is(T == HTTP2HeaderTableField))
{
	private {
		static if(is(T == HTTP2HeaderTableField)) T[] m_range;
		else T m_range;
		IndexingTable m_table;
		ubyte[] m_encoded;
	}

	bool huffman;

	this(T range, IndexingTable table, bool huff = true) @trusted
	{
		static if(is(T == HTTP2HeaderTableField)) m_range ~= range;
		else m_range = range;

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

		/// encode a pure integer (present in table) or integer name + literal value
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
					if(header.index) bbuf.put(cast(ubyte)((idx + 64) & 127));
					else if (header.neverIndex) bbuf.put(cast(ubyte)((idx + 16) & 31));
					else bbuf.put(cast(ubyte)(idx & 15));
					// encode value as literal
					encodeLiteralField(to!string(header.value), bbuf);

					m_encoded = bbuf.data;
					return true;
				}
				idx++;
			}
			return false;
		}

		/// encode a literal field depending on its indexing requirements
		void encodeLiteral(const HTTP2HeaderTableField header) @safe
		{
			auto bbuf = appender!(ubyte[]); // TODO a proper allocatorA

			if(header.index) bbuf.put(cast(ubyte)(64));
			else if(header.neverIndex) bbuf.put(cast(ubyte)(16));
			else bbuf.put(cast(ubyte)(0));

			encodeLiteralField(to!string(header.name), bbuf);
			encodeLiteralField(to!string(header.value), bbuf);

			m_encoded = bbuf.data;
		}

		/// encode a field (name / value) using huffman or raw encoding
		void encodeLiteralField(Out)(string src, ref Out dst) @safe
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
	HTTP2HeaderTableField h1 = HTTP2HeaderTableField("custom-key", "custom-header");
	auto e1 = HeaderEncoder!(HTTP2HeaderTableField)(h1, table, false);
	auto d1 = HeaderDecoder!(ubyte[])(e1.front, table);
	assert(d1.front == h1);

	/** 1bis. Literal header field w. indexing (huffman encoded)
	  * :authority: www.example.com
	  */
	HTTP2HeaderTableField h1b = HTTP2HeaderTableField(":authority", "www.example.com");
	auto e1b = HeaderEncoder!(HTTP2HeaderTableField)(h1b, table);
	auto d1b = HeaderDecoder!(ubyte[])(e1b.front, table);
	assert(d1b.front == h1b);

	/** 2. Literal header field without indexing (raw)
	  * :path: /sample/path
	  */
	HTTP2HeaderTableField h2 = HTTP2HeaderTableField(":path", "/sample/path");
	// initialize with huffman=false (can be modified by e2.huffman)
	auto e2 = HeaderEncoder!(HTTP2HeaderTableField)(h2, table, false);
	auto d2 = HeaderDecoder!(ubyte[])(e2.front, table);
	assert(d2.front == h2);

	/** 3. Literal header field never indexed (raw)
	  * password: secret
	  */
	// TODO encodeLiteral
	HTTP2HeaderTableField h3 = HTTP2HeaderTableField("password", "secret");
	h3.neverIndex = true;
	h3.index = false;
	auto e3 = HeaderEncoder!HTTP2HeaderTableField(h3, table, false);
	auto d3 = HeaderDecoder!(ubyte[])(e3.front, table);
	assert(d3.front == h3);

	/** 4. Indexed header field (integer) 
	  * :method: GET
	  */
	HTTP2HeaderTableField h4 = HTTP2HeaderTableField(":method", HTTPMethod.GET);
	auto e4 = HeaderEncoder!(HTTP2HeaderTableField)(h4, table);
	auto d4 = HeaderDecoder!(ubyte[])(e4.front, table);
	assert(d4.front == h4);

}
