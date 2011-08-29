#ifndef __MPEGTSH264_H__
#define __MPEGTSH264_H__

#include "Segmenter.hpp"
#include <set>

#define TS_PACKET_SIZE 188
#define TS_DUMMY_PID 0x2000 // Out of range, will never match

namespace Segmenter {

class MpegtsH264: public Segmenter {
private:
	long long m_pcr_length;
	signed long long m_pcr_segstart;
	bool m_idr;
	char m_pat[TS_PACKET_SIZE], m_pmt[TS_PACKET_SIZE], m_pkt[TS_PACKET_SIZE];
	typedef unsigned short pid_t;
	pid_t m_pmt_pid, m_h264_pid;
	std::set<pid_t> m_media_pids;

public:
	MpegtsH264(const unsigned long length, const std::string extra_opts);
	virtual ~MpegtsH264();
	static void usage();
	virtual float copy_segment(std::istream *in, std::ostream *out);
};

} // namespace

#endif
