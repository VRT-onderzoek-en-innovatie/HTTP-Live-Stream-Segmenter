#ifndef __BYTECOUNT_H__
#define __BYTECOUNT_H__

#include "Segmenter.hpp"
#include <string>
#include <stdexcept>

namespace Segmenter {

class ByteCount : protected Segmenter {
private:
	unsigned long m_length;
	unsigned long m_block;
	char *m_buffer;

public:
	ByteCount(const unsigned long length, const std::string extra_opts);	
	virtual ~ByteCount();
	static void usage();
	virtual float copy_segment(std::istream *in, std::ostream *out);
};

} // namespace

#endif

// vim: set ts=4 sw=4:
