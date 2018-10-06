//module vibe.http.internal.hpack.tables;
module HPACK.tables;

import vibe.http.status;
import vibe.http.common;
import vibe.http.internal.http2;
import vibe.core.log;

import std.variant;
import std.container.dlist;
import std.traits;
import std.meta;
import std.range;
import taggedalgebraic;

/*
	2.3.  Indexing Tables

	HPACK uses two tables for associating header fields to indexes.  The
	static table (see Section 2.3.1) is predefined and contains common
	header fields (most of them with an empty value).  The dynamic table
	(see Section 2.3.2) is dynamic and can be used by the encoder to
	index header fields repeated in the encoded header lists.

	These two tables are combined into a single address space for
	defining index values (see Section 2.3.3).

 2.3.1.  Static Table

	The static table consists of a predefined static list of header
	fields.  Its entries are defined in Appendix A.

 2.3.2.  Dynamic Table

	The dynamic table consists of a list of header fields maintained in
	first-in, first-out order.  The first and newest entry in a dynamic
	table is at the lowest index, and the oldest entry of a dynamic tabl
	is at the highest index.
	The dynamic table is initially empty.  Entries are added as each
	header block is decompressed.

	The dynamic table is initially empty.  Entries are added as each
	header block is decompressed.

	The dynamic table can contain duplicate entries (i.e., entries with
	the same name and same value).  Therefore, duplicate entries MUST NOT
	be treated as an error by a decoder.

	The encoder decides how to update the dynamic table and as such can
	control how much memory is used by the dynamic table.  To limit the
	memory requirements of the decoder, the dynamic table size is
	strictly bounded (see Section 4.2).

	The decoder updates the dynamic table during the processing of a list
	of header field representations (see Section 3.2).
*/

// wraps a header field = name:value
struct HTTP2HeaderTableField {
	private union HeaderValue {
		string str;
		string[] strarr;
		HTTPStatus status;
		HTTPMethod method;
	}

	string name;
	TaggedAlgebraic!HeaderValue value;

	// initializers
	static foreach(t; __traits(allMembers, HeaderValue)) {
		mixin("this(string n, " ~
				typeof(__traits(getMember, HeaderValue, t)).stringof ~
				" v) { name = n; value = v; }");
	}
}

// fixed as per HPACK RFC
immutable size_t STATIC_TABLE_SIZE = 61;

/** static table to index most common headers
  * fixed size, fixed order of entries (read only)
  * cannot be updated while decoding a header block
  */
static immutable HTTP2HeaderTableField[size_t] StaticTable;

shared static this() {
	StaticTable = [
		1:	   HTTP2HeaderTableField(":authority", ""),
		2:	   HTTP2HeaderTableField(":method", HTTPMethod.GET),
		3:	   HTTP2HeaderTableField(":method", HTTPMethod.POST),
		4:	   HTTP2HeaderTableField(":path", "/"),
		5:	   HTTP2HeaderTableField(":path", "/index.html"),
		6:	   HTTP2HeaderTableField(":scheme", "http"),
		7:	   HTTP2HeaderTableField(":scheme", "https"),
		8:	   HTTP2HeaderTableField(":status", HTTPStatus.ok), 					// 200
		9:	   HTTP2HeaderTableField(":status", HTTPStatus.noContent), 				// 204
		10:	   HTTP2HeaderTableField(":status", HTTPStatus.partialContent), 		// 206
		11:	   HTTP2HeaderTableField(":status", HTTPStatus.notModified), 			// 304
		12:	   HTTP2HeaderTableField(":status", HTTPStatus.badRequest), 			// 400
		13:	   HTTP2HeaderTableField(":status", HTTPStatus.notFound), 				// 404
		14:	   HTTP2HeaderTableField(":status", HTTPStatus.internalServerError), 	// 500
		15:	   HTTP2HeaderTableField("accept-charset", ""),
		16:	   HTTP2HeaderTableField("accept-encoding", ["gzip", "deflate"]),
		17:	   HTTP2HeaderTableField("accept-language", ""),
		18:	   HTTP2HeaderTableField("accept-ranges", ""),
		19:	   HTTP2HeaderTableField("accept", ""),
		20:	   HTTP2HeaderTableField("access-control-allow-origin", ""),
		21:	   HTTP2HeaderTableField("age", ""),
		22:	   HTTP2HeaderTableField("allow", ""),
		23:	   HTTP2HeaderTableField("authorization", ""),
		24:	   HTTP2HeaderTableField("cache-control", ""),
		25:	   HTTP2HeaderTableField("content-disposition", ""),
		26:	   HTTP2HeaderTableField("content-encoding", ""),
		27:	   HTTP2HeaderTableField("content-language", ""),
		28:	   HTTP2HeaderTableField("content-length", ""),
		29:	   HTTP2HeaderTableField("content-location", ""),
		30:	   HTTP2HeaderTableField("content-range", ""),
		31:	   HTTP2HeaderTableField("content-type", ""),
		32:	   HTTP2HeaderTableField("cookie", ""),
		33:	   HTTP2HeaderTableField("date", ""),
		34:	   HTTP2HeaderTableField("etag", ""),
		35:	   HTTP2HeaderTableField("expect", ""),
		36:	   HTTP2HeaderTableField("expires", ""),
		37:	   HTTP2HeaderTableField("from", ""),
		38:	   HTTP2HeaderTableField("host", ""),
		39:	   HTTP2HeaderTableField("if-match", ""),
		40:	   HTTP2HeaderTableField("if-modified-since", ""),
		41:	   HTTP2HeaderTableField("if-none-match", ""),
		42:	   HTTP2HeaderTableField("if-range", ""),
		43:	   HTTP2HeaderTableField("if-unmodified-since", ""),
		44:	   HTTP2HeaderTableField("last-modified", ""),
		45:	   HTTP2HeaderTableField("link", ""),
		46:	   HTTP2HeaderTableField("location", ""),
		47:	   HTTP2HeaderTableField("max-forwards", ""),
		48:	   HTTP2HeaderTableField("proxy-authenticate", ""),
		49:	   HTTP2HeaderTableField("proxy-authorization", ""),
		50:	   HTTP2HeaderTableField("range", ""),
		51:	   HTTP2HeaderTableField("referer", ""),
		52:	   HTTP2HeaderTableField("refresh", ""),
		53:	   HTTP2HeaderTableField("retry-after", ""),
		54:	   HTTP2HeaderTableField("server", ""),
		55:	   HTTP2HeaderTableField("set-cookie", ""),
		56:	   HTTP2HeaderTableField("strict-transport-security", ""),
		57:	   HTTP2HeaderTableField("transfer-encoding", ""),
		58:	   HTTP2HeaderTableField("user-agent", ""),
		59:	   HTTP2HeaderTableField("vary", ""),
		60:	   HTTP2HeaderTableField("via", ""),
		61:	   HTTP2HeaderTableField("www-authenticate", "")
	];
}

private struct DynamicTable {
	private {
		// table is a queue, initially empty
		DList!HTTP2HeaderTableField m_table;

		// as defined in SETTINGS_HEADER_TABLE_SIZE
		HTTP2SettingValue m_maxsize;

		// current size
		size_t m_size = 0;

		// last index (table index starts from 1)
		size_t m_index = 0;
	}

	this(HTTP2SettingValue ms) @safe
	{
		m_maxsize = ms;
	}

	// number of elements inside dynamic table
	@property size_t size() @safe { return m_size; }

	@property size_t index() @safe { return m_index; }

	@property ref auto table() @safe { return m_table; }

	HTTP2HeaderTableField opIndex(size_t idx) @safe
	{
		foreach(i,f; m_table[].enumerate(1)) {
			 if(i == idx) return f;
		}
		assert(false, "Invalid dynamic table index");
	}

	// insert at the head
	void insert(HTTP2HeaderTableField header) @safe
	{
		auto nsize = computeESize(header);
		// ensure that the new entry does not exceed table capacity
		while(m_size + nsize > m_maxsize) {
			logDebug("Maximum header table size exceeded");
			remove();
		}

		// insert
		m_table.insertFront(header);
		m_size += nsize;
		m_index++;
	}

	// evict an entry
	void remove() @safe
	{
		assert(!m_table.empty, "Cannot remove element from empty table");
		m_size -= computeESize(m_table.back);
		m_table.removeBack();
		m_index--;
	}

	/** new size should be lower than the max set one
	  * after size is successfully changed, an ACK has to be sent
	  * multiple changes between two header fields are possible
	  * if multiple changes occour, only the smallest maximum size
	  * requested has to be acknowledged
	*/
	void updateMaxSize(size_t nsize) @safe
	{
		assert(false);
	}

	// compute size of an entry as per RFC
	private size_t computeESize(HTTP2HeaderTableField f) @safe
	{
		return f.name.sizeof + f.value.sizeof + 32;
	}
}

unittest {
	// static table
	auto a = StaticTable[1];
	static assert(is(typeof(a) == immutable(HTTP2HeaderTableField)));
	assert(a.name == ":authority");
	assert(StaticTable[2].name == ":method" && StaticTable[2].value == HTTPMethod.GET);

	HTTP2Settings settings;

	DynamicTable dt = DynamicTable(settings.headerTableSize);
	assert(dt.size == 0);
	assert(dt.index == 0);

	// dynamic table
	import std.algorithm.comparison : equal;

	auto h = HTTP2HeaderTableField("test", "testval");
	dt.insert(h);
	assert(dt.size > 0);
	assert(dt.index == 1);
	assert(equal(dt.table[], [h]));
	assert(dt.table[].front.name == "test");
	assert(dt[dt.index].name == "test");

	dt.remove();
	assert(dt.size == 0);
	assert(dt.index == 0);
}

/** provides an unified address space through operator overloading
  * this is the only interface that will be used for the two tables
  */
struct IndexingTable {
	private {
		alias StaticTable m_static;
		DynamicTable m_dynamic;
	}

	// requires the maximum size for the dynamic table
	this(HTTP2SettingValue ms) @safe
	{
		m_dynamic = DynamicTable(ms);
	}

	@property size_t size() @safe { return STATIC_TABLE_SIZE + m_dynamic.index; }

	// element retrieval
	HTTP2HeaderTableField opIndex(size_t idx) @safe
	{
		assert(idx <= size(), "Invalid table index");

		if (idx <= STATIC_TABLE_SIZE) return m_static[idx];
		else return m_dynamic[idx-STATIC_TABLE_SIZE];
	}

	// forward to insert
	auto opOpAssign(string op)(HTTP2HeaderTableField hf) @safe
		if(op == "+")
	{
		insert(hf);
	}

	// dollar == size
	// +1 to mantain consistency with the dollar operator
	size_t opDollar() @safe
	{
		return size() + 1;
	}

	// assignment can only be done on the dynamic table
	void insert(HTTP2HeaderTableField hf) @safe
	{
		m_dynamic.insert(hf);
	}
}

unittest {
	// indexing table
	HTTP2Settings settings;
	IndexingTable table = IndexingTable(settings.headerTableSize);
	assert(table[2].name == ":method" && table[2].value == HTTPMethod.GET);

	// assignment
	auto h = HTTP2HeaderTableField("test", "testval");
	table += h;
	assert(table.size == STATIC_TABLE_SIZE + 1);
	assert(table[STATIC_TABLE_SIZE+1].name == "test");

	auto h2 = HTTP2HeaderTableField("test2", "testval2");
	table.insert(h2);
	assert(table.size == STATIC_TABLE_SIZE + 2);
	assert(table[STATIC_TABLE_SIZE+1].name == "test2");

	// dollar
	auto h3 = HTTP2HeaderTableField("test3", "testval3");
	table += h3;
	assert(table.size == STATIC_TABLE_SIZE + 3);
	assert(table[$-1].name == "test");
	assert(table[$ - 2].name == "test2");
	assert(table[STATIC_TABLE_SIZE+1].name == "test3");

	// test removal on full table
	HTTP2SettingValue hts = h.name.sizeof + h.value.sizeof + 32; // only one header
	IndexingTable t2 = IndexingTable(hts);
	t2 += h;
	t2 += h;
	assert(t2.size == STATIC_TABLE_SIZE + 1);
	assert(t2[STATIC_TABLE_SIZE + 1].name == "test");
	assert(t2[$ - 1].name == "test");
}
