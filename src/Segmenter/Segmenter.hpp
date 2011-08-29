#ifndef __SEGMENTER_H__
#define __SEGMENTER_H__

#include <fstream>

namespace Segmenter {

/* abstract */ class Segmenter {
public:
	Segmenter(const unsigned long length, const std::string extra_opts) {}
	/* Called after parsing the command line options
	 * length is the target segment duration in seconds
	 * if extra options are specified on the command line, extr_opts
	 * points to this string; otherwise extra_opts is NULL
	 */

	virtual ~Segmenter() {}
	/* Descructor
	 */
	
	static void usage() {}
	/* Print whatever useful info to stderr
	 */

	virtual float copy_segment(std::istream *in, std::ostream *out) = 0;
	/* The absolute value of the return value must be the number of seconds effectively copied.
	 * A value <=0 indicated end of stream
	 */
};

} // namespace

#endif
