#include "ByteCount.hpp"
#include <stdlib.h>
#include <sstream>

namespace Segmenter {

ByteCount::ByteCount(unsigned long length, const std::string extra_opts) :
	Segmenter(length, extra_opts),
	m_length( length ),
	m_block( 1024 ) {
	if( extra_opts != "" ) {
		char *tmp;
		m_block = strtol(extra_opts.c_str(), &tmp, 10);
		if( extra_opts.c_str() == tmp ) {
			std::ostringstream msg;
			msg << "Invalid extra-options \"" << extra_opts << "\": Not an integer";
			throw std::invalid_argument(msg.str());
		}
	}
	if( (m_buffer = static_cast<char*>(malloc(m_block))) == NULL )
		throw std::bad_alloc();
}

ByteCount::~ByteCount() {
	free(m_buffer);
}

void ByteCount::usage() {
}

float ByteCount::copy_segment(std::istream *in, std::ostream *out) {
	unsigned long i;
	for( i=0; i < m_length; i++ ) {
		try{ 
			in->read(m_buffer, m_block);
		} catch( std::ios_base::failure e ) {
			// We handle EOF ourself; throw the rest
			if( ! in->eof() ) throw;
		}
		out->write(m_buffer, in->gcount() ); // count may be less than m_block
		if( in->eof() ) return -i;
	}
	return i;
}

} // namespace

// vim: set ts=4 sw=4:
