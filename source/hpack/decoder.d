module HPACK.decoder;

import HPACK.exception;
import HPACK.huffman;
import HPACK.tables;
import HPACK.util;
<<<<<<< HEAD
=======

<<<<<<< HEAD
import vibe.http.internal.http2;
>>>>>>> cc1827c... trailing spaces

=======
>>>>>>> bac8020... removed unused dependency to vibe-http
import std.range; // Decoder
<<<<<<< HEAD
<<<<<<< HEAD
import std.string : representation;
import std.array;
import std.typecons : tuple;
=======
import std.bitmanip; // prefix encoding / decoding
=======
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
import std.string : representation;
<<<<<<< HEAD
>>>>>>> 085094d... m_range as immutable, std.string.representation
=======
import std.array;
<<<<<<< HEAD
>>>>>>> d64b1a5... decodeHuffman output-range based
=======
import std.typecons : tuple;
>>>>>>> aacd388... indexing information in front

/** Module to implement an header decoder consistent with HPACK specifications (RFC 7541)
  * The detailed description of the decoding process, examples and binary format details can
  * be found at:
  * Section 3: https://tools.ietf.org/html/rfc7541#section-3
  * Section 6: https://tools.ietf.org/html/rfc7541#section-6
  * Appendix C: https://tools.ietf.org/html/rfc7541#appendix-C
*/
<<<<<<< HEAD
<<<<<<< HEAD
alias HTTP2SettingValue = uint;
=======
>>>>>>> cc1827c... trailing spaces
=======
alias HTTP2SettingValue = uint;
>>>>>>> bac8020... removed unused dependency to vibe-http

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
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
=======
		HTTP2HeaderTableField[] m_index; // to be appended
		HTTP2HeaderTableField[] m_noindex;
>>>>>>> 1ce5894... lazily evaluated input range
=======
		bool m_index = true;
		bool m_neverIndex = false;
>>>>>>> aacd388... indexing information in front
=======
>>>>>>> cad98a7... fixup indexing information
	}

	this(T range, IndexingTable table) @trusted
	{
<<<<<<< HEAD
<<<<<<< HEAD
=======
		//static if(is(ElementType!T : char)) m_range = cast(ubyte[])range;
>>>>>>> 085094d... m_range as immutable, std.string.representation
=======
>>>>>>> aacd388... indexing information in front
		static if(is(typeof(representation(range)) == immutable(ubyte)[])) m_range = range;
		else m_range = cast(immutable(ubyte)[])range;

		m_table = table;

		decode();
	}

// InputRange specific methods
<<<<<<< HEAD
<<<<<<< HEAD
	@property bool empty() @safe @nogc { return m_range.empty; }

	@property auto front() @safe @nogc { return m_decoded; }
=======
	@property bool empty() @safe { return m_range.empty; }

	@property HTTP2HeaderTableField front() @safe { return m_decoded; }
>>>>>>> 1ce5894... lazily evaluated input range

	void popFront() @safe
	{
<<<<<<< HEAD
		assert(!empty, "Cannot call popFront on an empty HeaderDecoder");
=======
		enforce!HPACKException(!empty, "Cannot call popFront on an empty HeaderDecoder");
>>>>>>> 1ce5894... lazily evaluated input range
=======
	@property bool empty() @safe @nogc { return m_range.empty; }

	@property auto front() @safe @nogc { return m_decoded; }

	void popFront() @safe
	{
		assert(!empty, "Cannot call popFront on an empty HeaderDecoder");
>>>>>>> 89e40cd... @nogc and removed std.bitmanip

		// advance if data is still available
		decode();
	}

	void put(T)(T range) @trusted
	{
		static if(is(typeof(representation(range)) == immutable(ubyte)[])) m_range = range;
<<<<<<< HEAD
<<<<<<< HEAD
		else m_range ~= cast(immutable(ubyte)[])range;
=======
		else m_range = cast(immutable(ubyte)[])range;
>>>>>>> 1ce5894... lazily evaluated input range
=======
		else m_range ~= cast(immutable(ubyte)[])range;
>>>>>>> 89e40cd... @nogc and removed std.bitmanip

		decode();
	}

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
	@property bool toIndex() @safe @nogc { return m_decoded.index; }

	@property bool neverIndexed() @safe @nogc { return m_decoded.neverIndex; }
=======
	@property HTTP2HeaderTableField[] toIndex() @safe @nogc { return m_index; }

	@property HTTP2HeaderTableField[] neverIndexed() @safe @nogc { return m_noindex; }
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
=======
	@property bool toIndex() @safe @nogc { return m_index; }

	@property bool neverIndexed() @safe @nogc { return m_neverIndex; }
>>>>>>> aacd388... indexing information in front
=======
	@property bool toIndex() @safe @nogc { return m_decoded.index; }

	@property bool neverIndexed() @safe @nogc { return m_decoded.neverIndex; }
>>>>>>> cad98a7... fixup indexing information

// decoding
	private {

		void decode() @safe
		{
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
			ubyte bbuf = m_range[0];
			m_range = m_range[1..$];

			if(bbuf & 128) {
=======
			auto bbuf = m_range[0].toBitArray();
			m_range = m_range[1..$];

			if(bbuf[0]) {
>>>>>>> 1ce5894... lazily evaluated input range
=======
			ubyte bbuf = m_range[0];
			m_range = m_range[1..$];

			if(bbuf & 128) {
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
				auto res = decodeInteger(bbuf);
				m_decoded = m_table[res];
			} else {
				HTTP2HeaderTableField hres;
				bool update = false;

<<<<<<< HEAD
<<<<<<< HEAD
				if (bbuf & 64) { // inserted in dynamic table
=======
				if (bbuf[1]) { // inserted in dynamic table
>>>>>>> 1ce5894... lazily evaluated input range
=======
				if (bbuf & 64) { // inserted in dynamic table
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
					auto idx = bbuf.toInteger(2);
					if(idx > 0) {  // name == table[index].name, value == literal
						hres.name = m_table[idx].name;
					} else {   // name == literal, value == literal
						hres.name = decodeLiteral();
					}
					hres.value = decodeLiteral();
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
					hres.index = true;
					hres.neverIndex = false;

				} else if(bbuf & 16) { // NEVER inserted in dynamic table
=======
					m_index ~= hres;
=======
					m_index = true;
					m_neverIndex = false;
>>>>>>> aacd388... indexing information in front
=======
					hres.index = true;
					hres.neverIndex = false;
>>>>>>> cad98a7... fixup indexing information

<<<<<<< HEAD
				} else if(bbuf[3]) { // NEVER inserted in dynamic table
>>>>>>> 1ce5894... lazily evaluated input range
=======
				} else if(bbuf & 16) { // NEVER inserted in dynamic table
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
					auto idx = bbuf.toInteger(4);
					if(idx > 0) {  // name == table[index].name, value == literal
						hres.name = m_table[idx].name;
					} else {   // name == literal, value == literal
						hres.name = decodeLiteral();
					}
					hres.value = decodeLiteral();
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
					hres.index = false;
					hres.neverIndex = true;

				} else if(!(bbuf & 32)) { // this occourrence is not inserted in dynamic table
=======
					m_noindex ~= hres;
=======
					m_index = false;
					m_neverIndex = true;

>>>>>>> aacd388... indexing information in front
=======
					hres.index = false;
					hres.neverIndex = true;
>>>>>>> cad98a7... fixup indexing information

<<<<<<< HEAD
				} else if(!bbuf[2]) { // this occourrence is not inserted in dynamic table
>>>>>>> 1ce5894... lazily evaluated input range
=======
				} else if(!(bbuf & 32)) { // this occourrence is not inserted in dynamic table
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
					auto idx = bbuf.toInteger(4);
					if(idx > 0) {  // name == table[index].name, value == literal
						hres.name = m_table[idx].name;
					} else {   // name == literal, value == literal
						hres.name = decodeLiteral();
<<<<<<< HEAD
					}
					hres.value = decodeLiteral();
<<<<<<< HEAD
<<<<<<< HEAD
					hres.index = hres.neverIndex = false;
=======
					m_index = m_neverIndex = false;
>>>>>>> aacd388... indexing information in front
=======
					hres.index = hres.neverIndex = false;
>>>>>>> cad98a7... fixup indexing information

				} else { // dynamic table size update (bbuf[2] is set)
					update = true;
					auto nsize = bbuf.toInteger(3);
					m_table.updateSize(cast(HTTP2SettingValue)nsize);
=======
			while(!m_range.empty) {
				auto bbuf = m_range[0].toBitArray();
				m_range = m_range[1..$];

				if(bbuf[0]) {
					auto res = decodeInteger(bbuf);
					m_decoded ~= m_table[res];
				} else {
					HTTP2HeaderTableField hres;
					bool update = false;

					if (bbuf[1]) { // inserted in dynamic table
						auto idx = bbuf.toInteger(2);
						if(idx > 0) {  // name == table[index].name, value == literal
							hres.name = m_table[idx].name;
						} else {   // name == literal, value == literal
							hres.name = decodeLiteral();
						}
						hres.value = decodeLiteral();
						m_index ~= hres;

					} else if(bbuf[3]) { // NEVER inserted in dynamic table
						auto idx = bbuf.toInteger(4);
						if(idx > 0) {  // name == table[index].name, value == literal
							hres.name = m_table[idx].name;
						} else {   // name == literal, value == literal
							hres.name = decodeLiteral();
						}
						hres.value = decodeLiteral();
						m_noindex ~= hres;

					} else if(!bbuf[2]) { // this occourrence is not inserted in dynamic table
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
=======
>>>>>>> 1ce5894... lazily evaluated input range
					}
					hres.value = decodeLiteral();

<<<<<<< HEAD
<<<<<<< HEAD
					default:
						assert(false, "Invalid header block.");
>>>>>>> 9320f77... fixup m_range element pop
=======
					if(!update) m_decoded ~= hres;
>>>>>>> fa230bf... fixup switch
				}
<<<<<<< HEAD
<<<<<<< HEAD
				assert(!(hres.index && hres.neverIndex), "Invalid header indexing information");
=======
				} else { // dynamic table size update (bbuf[2] is set)
					update = true;
					auto nsize = bbuf.toInteger(3);
					m_table.updateSize(cast(HTTP2SettingValue)nsize);
				}
>>>>>>> 1ce5894... lazily evaluated input range
=======
				assert(!(m_index && m_neverIndex), "Invalid header indexing information");
>>>>>>> aacd388... indexing information in front
=======
				assert(!(hres.index && hres.neverIndex), "Invalid header indexing information");
>>>>>>> cad98a7... fixup indexing information

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
<<<<<<< HEAD
<<<<<<< HEAD
					bbuf = m_range[0];
=======
					bbuf = m_range[0].toBitArray();
>>>>>>> 9320f77... fixup m_range element pop
=======
					bbuf = m_range[0];
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
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
<<<<<<< HEAD
<<<<<<< HEAD
			ubyte bbuf = m_range[0];
=======
			auto bbuf = m_range[0].toBitArray();
>>>>>>> 9320f77... fixup m_range element pop
			m_range = m_range[1..$];

			auto res = appender!string; // TODO a proper allocator
=======
			ubyte bbuf = m_range[0];
			m_range = m_range[1..$];

<<<<<<< HEAD
			string res;
>>>>>>> 89e40cd... @nogc and removed std.bitmanip
=======
			auto res = appender!string; // TODO a proper allocator
>>>>>>> d64b1a5... decodeHuffman output-range based
			bool huffman = (bbuf & 128) ? true : false;


			assert(!m_range.empty, "Cannot decode from empty range block");

			// take a buffer of remaining octets
			auto vlen = bbuf.toInteger(1); // value length
			auto buf = m_range[0..vlen];
			m_range = m_range[vlen..$];

			if(huffman) { // huffman encoded
				decodeHuffman(buf, res);
			} else { // raw encoded
				res.put(buf);
			}
			return res.data;
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
	assert(decoder.front.index);

	/** 1bis. Literal header field w. indexing (huffman encoded)
	  * :authority: www.example.com
	  */
	block = [0x41, 0x8c, 0xf1, 0xe3, 0xc2, 0xe5, 0xf2, 0x3a, 0x6b, 0xa0, 0xab, 0x90, 0xf4, 0xff];
	decoder.put(block);
<<<<<<< HEAD
<<<<<<< HEAD
	assert(decoder.front.name == ":authority" && decoder.front.value == "www.example.com");
<<<<<<< HEAD
	assert(decoder.front.index);
=======
	assert(decoder.toIndex.back.name == ":authority" && decoder.toIndex.back.value == "www.example.com");
>>>>>>> 1ce5894... lazily evaluated input range
=======
	assert(decoder.front.data.name == ":authority" && decoder.front.data.value == "www.example.com");
=======
	assert(decoder.front.name == ":authority" && decoder.front.value == "www.example.com");
>>>>>>> cad98a7... fixup indexing information
	assert(decoder.front.index);
>>>>>>> aacd388... indexing information in front

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
<<<<<<< HEAD
<<<<<<< HEAD
	assert(decoder.front.name == "password" && decoder.front.value == "secret");
<<<<<<< HEAD
	assert(decoder.front.neverIndex);
=======
	assert(decoder.neverIndexed.back.name == "password" && decoder.neverIndexed.back.value == "secret");
>>>>>>> 1ce5894... lazily evaluated input range
=======
	assert(decoder.front.data.name == "password" && decoder.front.data.value == "secret");
=======
	assert(decoder.front.name == "password" && decoder.front.value == "secret");
>>>>>>> cad98a7... fixup indexing information
	assert(decoder.front.neverIndex);
>>>>>>> aacd388... indexing information in front


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
