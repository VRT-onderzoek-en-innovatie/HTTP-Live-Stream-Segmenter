#include "MP3.hpp"
#include <iostream>

// LCM of sample rates
#define FRAC_SECOND 14112000

namespace Segmenter {

static const unsigned short bitrate[][4][16] = {
        {/* MPEG 2.5 */
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0},
        /* Layer 3 */ {  0,   8,  16,  24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160,   0},
        /* Layer 2 */ {  0,   8,  16,  24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160,   0},
        /* Layer 1 */ {  0,  32,  48,  56,  64,  80,  96, 112, 128, 144, 160, 176, 192, 224, 256,   0}
        },
        {/*        */
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0},
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0},
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0},
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0}
        },
        {/* MPEG 2 */
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0},
        /* Layer 3 */ {  0,   8,  16,  24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160,   0},
        /* Layer 2 */ {  0,   8,  16,  24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160,   0},
        /* Layer 1 */ {  0,  32,  48,  56,  64,  80,  96, 112, 128, 144, 160, 176, 192, 224, 256,   0}
        },
        {/* MPEG 1 */
        /*         */ {  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0},
        /* Layer 3 */ {  0,  32,  40,  48,  56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320,   0},
        /* Layer 2 */ {  0,  32,  48,  56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320, 384,   0},
        /* Layer 1 */ {  0,  32,  64,  96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448,   0}
        }
        };
static const unsigned short samplerate[][4] = {
        /* MPEG 2.5 */ {11025, 12000, 8000, 0},
        /*          */ {0, 0, 0, 0},
        /* MPEG 2   */ {22050, 24000, 16000, 0},
        /* MPEG 1   */ {44100, 48000, 32000, 0}};

MP3::MP3(const unsigned long length, const std::string extra_opts) :
	Segmenter(length, extra_opts),
	m_length(length),
	m_pos(0) {
}

float MP3::copy_segment(std::istream *in, std::ostream *out) {
	while( m_pos / FRAC_SECOND < m_length ) {
		
		try {
			char header[4];
			in->read(header, 4);

        	while( header[0] != static_cast<char>(0xff)
			   || (header[1] & 0xe0) != static_cast<char>(0xe0) ) {
				// We are not in sync
				do{
					in->read(header, 1);
				} while( header[0] != static_cast<char>(0xff) );
				
				in->read(header+1, 3);
			}
			
			unsigned char version_idx = (header[1] & 0x18) >> 3;
			unsigned char layer_idx = (header[1] & 0x06) >> 1;
			unsigned char bitrate_idx = (header[2] & 0xf0) >> 4;
			unsigned char samplerate_idx = (header[2] & 0x0c) >> 2;
			unsigned char padding = (header[2] & 0x02) >> 1;

			size_t len = 144 * bitrate[version_idx][layer_idx][bitrate_idx]*1000
				/ samplerate[version_idx][samplerate_idx]
				+ padding - 4;

			if( layer_idx == 3 ) { /* Layer */
				m_pos += 384 * (FRAC_SECOND / samplerate[version_idx][samplerate_idx]);
			} else {
				m_pos += 1152 * (FRAC_SECOND / samplerate[version_idx][samplerate_idx]);
			}
			
			char *buf = new char[len];
			
			in->read(buf, len);

			out->write(header, 4);
			out->write(buf, len);
			
			delete buf;
		} catch( std::ios_base::failure e ) {
			if( ! in->eof() ) throw;
			return -(m_pos / FRAC_SECOND);
		}
	}
    
	m_pos -= m_length * FRAC_SECOND; /* Keep our error, so we don't accumulate */
    return m_length + m_pos / FRAC_SECOND;
}

} // namespace

// vim: set ts=4 sw=4:
