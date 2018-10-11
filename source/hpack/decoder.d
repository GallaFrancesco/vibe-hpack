module HPACK.decoder;
// import HPACK.tables;
import HPACK.exception;
import HPACK.huffman;

import std.range; // Decoder
import std.bitmanip; // prefix encoding / decoding

/** implements an input range to decode an header block
  * m_table is a reference to the original table
  */
struct HeaderDecoder(Range) if (isInputRange!Range &&
								(is(ElementType!Range : const(char)[]) ||
								(is(ElementType!Range : const(ubyte)[])) ||
								(is(ElementType!Range : const(bool[])[]))))
{
	private {
		Range m_range;
		//IndexingTable m_table;
		HTTP2HeaderTableField[] m_decoded;
	}

	this(Range range, /*ref IndexingTable table*/) @safe
	{
		m_range = range;
		//m_table = table; TODO

		decode();
	}

// InputRange specific methods
	@property bool empty() @safe { return m_range.empty; }

	@property HTTP2HeaderTableField[] front() @safe { return m_decoded; }

	void popFront() @safe
	{
		enforce!HPACKException(!empty, "Cannot call popFront on an empty HeaderDecoder");

		m_range.popFront();

		// advance if data is still available
		if(!empty) decode();
	}

// decoding
	private {
		// decode HeaderBlock according to rfc
		void decode() @safe
		{
			while(!empty) {

				auto bbuf = m_range.take(1).toBitArray();
				m_range.popFront();

				switch(bbuf[0]) {
					case 1: // indexed (integer)
						uint nbits = 7;
						auto res = bbuf.toInteger(1);

						if (res < (1 << nbits) - 1) {
							//m_decoded ~= table[res]; // TODO
							break;
						} else {

							uint m = 0;
							do {
								// take another octet
								bbuf = m_range.take(1).toBitArray();
								m_range.popFront();
								// concatenate it to the result
								res = res + bbuf.toInteger(1)*(1 << m);
								m += 7;
							} while(bbuf[0] == 1);

							m_decoded ~= table[res]; // TODO
							assert(false, "missing table idx");
						}
						break;
					case 0: // literal
						if (bbuf[1]) { // inserted in dynamic table
							auto idx = bbuf.toInteger(2);

							if(idx != 0) {  // name == table[index].name, value == literal
								string val = decodeLiteral();
								m_decoded ~= HTTP2HeaderTableField(table[index].name, val);

							} else { // name == literal, value == literal
								string name = decodeLiteral();
								string value = decodeLiteral();
								m_decoded ~= HTTP2HeaderTableField(name, value);

							}
						} else { // not inserted in dynamic table

						}
						break;
					default:
						assert(false, "Unable to convert to BitArray");
				}
			}

		}

		string decodeLiteral() @safe
		{
			Range buf = m_range.take(1).toBitArray();
			m_range.popFront();
			string res;
			bool huffman = bbuf[0] ? true : false;

			auto vlen = bbuf.toInteger(1); // value length
			enforce!HPACKDecoderException(!empty && m_range.length > vlen,
					"Cannot decode raw octets from empty range");

			// take a buffer of remaining octets
			Range block = m_range.take(vlen);
			m_range.popFrontN(vlen);

			if(huff) { // huffman encoded
				res = decodeHuffman(buf);
			} else { // raw encoded
				res = cast(string)buf;
			}
			return res;
		}

		// decode byte (BitArray[8]) as integer representation
		size_t toInteger(BitArray bbuf, uint prefix) @safe
		{
			bbuf[0] = 0; // set the prefix bit to 0
			size_t res = 0;

			foreach(b; bbuf.bitsSet) {
				res |= 1 << (7 - b);
			}
			return res;
		}

		// convert ubyte to BitArray representation (nbits == arraylen*8)
		void toBitArray(T)(T data) @safe

			if(is(typeof(T) == ubyte[]) || is(typeof(T) == const(char[])) ||
				is(typeof(T) == const(bool[])) || is(typeof(T) == int))
		{
			BitArray bdata;
			static if(is(typeof(T) == int)) {
				// int to BitArray
				bdata = BitArray(cast(void[])[data], 8);
			} else {
				// char[], ubyte[], bool[] to BitArray
				bdata = BitArray(cast(void[])data, data.length*8);
			}
			return bdata.reverse;
		}
	}

}

unittest {
	 // should test integer indexed representation
	 // TODO once table gets merged
}
