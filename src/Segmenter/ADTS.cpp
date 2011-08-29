#include "ADTS.hpp"
#include <assert.h>
#include <iostream>

// LCM of sample rates
#define FRAC_SECOND 28224000

namespace Segmenter {

static const unsigned long samplerate[] = {
	96000,
	88200,
	64000,
	48000,
	44100,
	32000,
	24000,
	22050,
	16000,
	12000,
	11025,
	8000};

ADTS::ADTS(const unsigned long length, const std::string extra_opts) :
	Segmenter(length, extra_opts),
	m_length(length),
	m_pos(0) {
}

float ADTS::copy_segment(std::istream *in, std::ostream *out) {
	while( m_pos / FRAC_SECOND < m_length ) {
		try {
			unsigned char header[7];
			in->read(reinterpret_cast<char*>(header), 7);

			// Are we in sync?
			while( header[0] != 0xff
			   || (header[1] & 0xe0) != 0xe0 ) {
				std::cerr << "Lost sync, skipping byte\n";
				do{
					in->read(reinterpret_cast<char*>(header), 1);
				} while( header[0] != 0xff );

				in->read(reinterpret_cast<char*>(header+1), 6);
			}

			unsigned char samplerate_idx = (header[2] & 0x3c) >> 2;
			size_t len = ((header[3] & 0x02) << 11) | (header[4] << 3) | ((header[5] & 0xe0) >> 5);
			len -= 7; // Header
			unsigned char num_blocks = (header[6] & 0x03) + 1;
			assert(num_blocks == 1); // TODO

			m_pos += 1024 * (FRAC_SECOND / samplerate[samplerate_idx]);
			
			char *buf = new char[len];

			in->read(buf, len);
			out->write(reinterpret_cast<char*>(header), 7);
			out->write(buf, len);

			delete buf;
		} catch ( std::ios_base::failure e ) {
			// EOF is handeled here
			if( ! in->eof() ) throw;
			return -(m_pos / FRAC_SECOND);
		}
	}

	m_pos -= m_length * FRAC_SECOND; /* Keep our error, so we don't accumulate */
	return m_length + m_pos / FRAC_SECOND;
}

} // namespace

// vim: set ts=4 sw=4:
