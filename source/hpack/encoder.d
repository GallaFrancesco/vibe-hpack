module HPACK.encoder;

import HPACK.tables;
import HPACK.huffman;
import HPACK.util;

import vibe.http.internal.http2;
import vibe.http.status;
import vibe.http.common;

import std.range;
import std.bitmanip; // prefix encoding / decoding


struct HeaderEncoder(T = HTTP2HeaderTableField[])
	if(isInputRange!T &&
	is(ElementType!T : HTTP2HeaderTableField))
{
	private {
		T m_range;
		IndexingTable m_table;
		ubyte[] m_encoded;
	}

	this(T range, IndexingTable table) @safe
	{
		m_range = range;
		m_table = table;

		encode();
	}

// InputRange specific methods
	@property bool empty() @safe { return m_encoded.empty; }

	@property HTTP2HeaderTableField front() @safe { return m_encoded.front; }

	@property HTTP2HeaderTableField back() @safe { return m_encoded.back; }

	void popFront() @trusted
	{
		enforce!HPACKException(!empty, "Cannot call popFront on an empty HeaderDecoder");

		m_encoded.popFront();

		// advance if data is still available
		if(!m_range.empty) encode();
	}

	@property HTTP2HeaderTableField opIndex(int idx) @safe
	{
		assert(idx < m_encoded.length, "Invalid encoder index");
		return m_encoded[idx];
	}

	@property HTTP2HeaderTableField[] opSlice(int start, int end) @safe
	{
		assert(start >= 0 && end < m_encoded.length, "Invalid encoder slice");
		return m_encoded[start..end];
	}

	void put(T)(T range) @safe
	{
		static if(is(ElementType!T : char)) m_range ~= cast(ubyte[])range;
		else m_range ~= range;

		encode();
	}

	private {
		void encode() @safe
		{
			while(!m_range.empty) {
				// pop a header
				auto header = m_range[0];
				m_range = m_range[1..$];

				// try to encode as integer
				bool indexed = encodeInteger(header);
				if(!indexed) encodeLiteral(header);
			}
		}

		bool encodeInteger(const HTTP2HeaderTableField header) @safe {
			// check table for indexed headers
			size_t idx = 0;
			foreach (h; m_table) {
				// encode both name / value as index
				if(h.name == header.name && h.value == header.value) {
					if(idx < 127) { // can be fit in one octet
						m_encoded ~= (cast(ubyte)idx + 128);
					} else { 		// must be split in multiple octets
						m_encoded ~= 255;
						idx -= 127;
						while (idx > 127) {
							m_encoded ~= ((idx % 128) + 128);
							idx = idx / 128;
						}
						m_encoded ~= cast(ubyte)idx & 127;
					}
					return true;

				// encode name as index, value as literal
				} else if(h.name == header.name && h.value == "") {
					// encode name as index ( always smaller than 64 )
					m_encoded ~= (cast(ubyte)idx ^ 64) & 127;
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
	import std.algorithm : find;
	import std.stdio;
	IndexingTable table;
	auto f = HTTP2HeaderTableField(":method", HTTPMethod.GET);

	writeln(table.find(f));
}
