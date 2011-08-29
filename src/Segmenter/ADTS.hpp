#ifndef __ADTS_H__
#define __ADTS_H__

#include "Segmenter.hpp"

namespace Segmenter {

class ADTS : protected Segmenter {
private:
	unsigned long m_length;
	unsigned long long m_pos;

public:
	ADTS(const unsigned long length, const std::string extra_opts);
	virtual ~ADTS() {}
	static void usage() {}
	virtual float copy_segment(std::istream *in, std::ostream *out);
};

} // namespace

#endif
