#ifndef __MP3_H__
#define __MP3_H__

#include "Segmenter.hpp"

namespace Segmenter {

class MP3 : protected Segmenter {
private:
	unsigned long m_length;
	unsigned long long m_pos;

public:
	MP3(const unsigned long length, const std::string extra_opts);
	virtual ~MP3() {}
	static void usage() {}
	virtual float copy_segment(std::istream *in, std::ostream *out);
};

} // namespace

#endif
