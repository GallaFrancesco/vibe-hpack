//module vibe.http.internal.hpack.hpack;
module hpack.hpack;

import hpack.encoder;
import hpack.decoder;
import hpack.tables;

import std.range;
import std.typecons;
import std.array; // appender
import std.algorithm.iteration;

void encodeHPACK(I,R)(I src, ref R dst, ref IndexingTable table, bool huffman = true) @safe
	if(is(I == HTTP2HeaderTableField) || is(ElementType!I : HTTP2HeaderTableField))
{
	static if(is(I == HTTP2HeaderTableField)) {
		src.encode(dst, table, huffman);
	} else if(is(ElementType!I : HTTP2HeaderTableField)){
		src.each!(h => h.encode(dst, table, huffman));
	}
}

unittest {
	// Following examples can be found in Appendix C of the HPACK RFC
	import vibe.http.status;
	import vibe.http.common;

	IndexingTable table = IndexingTable(4096);

	/** 1. Literal header field w. indexing (raw)
	  * custom-key: custom-header
	  */
	HTTP2HeaderTableField h1 = HTTP2HeaderTableField("custom-key", "custom-header");
	auto e1 = appender!(ubyte[]);
	h1.encodeHPACK(e1, table, false);
	auto d1 = HeaderDecoder!(ubyte[])(e1.data, table);
	assert(d1.front == h1);

	/** 1bis. Literal header field w. indexing (huffman encoded)
	  * :authority: www.example.com
	  */
	table.insert(HTTP2HeaderTableField(":authority", "www.example.com"));
	HTTP2HeaderTableField h1b = HTTP2HeaderTableField(":authority", "www.example.com");
	h1b.neverIndex = false;
	h1b.index = true;
	auto e1b = appender!(ubyte[]);
	h1b.encodeHPACK(e1b, table, true);
	auto d1b = HeaderDecoder!(ubyte[])(e1b.data, table);
	assert(d1b.front == h1b);

	/** 2. Literal header field without indexing (raw)
	  * :path: /sample/path
	  */
	HTTP2HeaderTableField h2 = HTTP2HeaderTableField(":path", "/sample/path");
	h2.neverIndex = false;
	h2.index = false;
	// initialize with huffman=false (can be modified by e2.huffman)
	auto e2 = appender!(ubyte[]);
	h2.encodeHPACK(e2, table, false);
	auto d2 = HeaderDecoder!(ubyte[])(e2.data, table);
	assert(d2.front == h2);

	/** 3. Literal header field never indexed (raw)
	  * password: secret
	  */
	HTTP2HeaderTableField h3 = HTTP2HeaderTableField("password", "secret");
	h3.neverIndex = true;
	h3.index = false;
	auto e3 = appender!(ubyte[]);
	h3.encodeHPACK(e3, table, false);
	auto d3 = HeaderDecoder!(ubyte[])(e3.data, table);
	assert(d3.front == h3);

	/** 4. Indexed header field (integer)
	  * :method: GET
	  */
	HTTP2HeaderTableField h4 = HTTP2HeaderTableField(":method", HTTPMethod.GET);
	auto e4 = appender!(ubyte[]);
	h4.encodeHPACK(e4, table);
	auto d4 = HeaderDecoder!(ubyte[])(e4.data, table);
	assert(d4.front == h4);

	/** 5. Full request without huffman encoding
	  * :method: GET
      * :scheme: http
      * :path: /
      * :authority: www.example.com
      * cache-control: no-cache
	  */
	HTTP2HeaderTableField[] block = [
		HTTP2HeaderTableField(":method", HTTPMethod.GET),
		HTTP2HeaderTableField(":scheme", "http"),
		HTTP2HeaderTableField(":path", "/"),
		HTTP2HeaderTableField(":authority", "www.example.com"),
		HTTP2HeaderTableField("cache-control", "no-cache")
	];

	ubyte[14] expected = [0x82, 0x86, 0x84, 0xbe, 0x58, 0x08, 0x6e, 0x6f, 0x2d, 0x63, 0x61, 0x63, 0x68, 0x65];
	auto bres = appender!(ubyte[]);
	block.encodeHPACK(bres, table, false);
	assert(bres.data == expected);

	/** 5. Full request with huffman encoding
	  * :method: GET
      * :scheme: http
      * :path: /
      * :authority: www.example.com
      * cache-control: no-cache
	  */
	ubyte[12] eexpected = [0x82, 0x86, 0x84, 0xbe, 0x58, 0x86, 0xa8, 0xeb, 0x10, 0x64, 0x9c, 0xbf];
	auto bbres = appender!(ubyte[]);
	block.encodeHPACK(bbres, table, true);
	assert(bbres.data == eexpected);
}

