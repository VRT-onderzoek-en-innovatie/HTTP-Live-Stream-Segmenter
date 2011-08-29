#include "MpegtsH264.hpp"
#include <iostream>
#include <stdexcept>
#include <string.h>

#define TS_SYNC_BYTE 0x47
#define PID(b) ( (( *(b) & 0x1f) << 8) | *(b+1) )
#define TS_PAYLOAD_UNIT_START(b) (b[1] & 0x40 )
#define TS_PAYLOAD_START(b) (4 + (b[3] & 0x20 ? 1+b[4] : 0))
#define TS_PCR_FREQ 90000LL

#define PAT_LENGTH(t) ( (t[1] & 0x0f) << 8 | t[2] )

#define PMT_LENGTH(t) ( (t[0] & 0x0f) << 8 | t[1] )
#define PMT_ES_LENGTH(t) ( (t[0] & 0x0f) << 8 | t[1] )
#define PMT_ES_TYPE(t) t[0]

#define STREAM_TYPE_VIDEO_H264      0x1b

namespace Segmenter {

MpegtsH264::MpegtsH264(const unsigned long length, const std::string extra_opts) :
	Segmenter(length, extra_opts),
	m_pcr_length( length * TS_PCR_FREQ ),
	m_pmt_pid( TS_DUMMY_PID ),
	m_h264_pid( TS_DUMMY_PID ) {
	m_idr = ( extra_opts.compare("IDR") == 0 );
	m_pat[0] = m_pmt[0] = 0x00;

	if( m_idr ) {
		std::cerr << "Splitting every IDR, ignoring timing\n";
	}
}

MpegtsH264::~MpegtsH264() {
}

void MpegtsH264::usage() {
	std::cerr << "Splits an MPEG-TS intelligently:\n"
	          << "Parses the PAT and PMT tables to identify the stream-type\n"
			  << "Cut the stream only right before the start of a new PES\n"
			  << "If the stream is h264, it will only cut before an IDR-frame\n"
			  << "\n"
			  << "extra options format:\n"
			  << "  [IDR]     if IDR is specified, the TS will be cut every IDR frame\n";
}


float MpegtsH264::copy_segment(std::istream *in, std::ostream *out) {
	if( m_pat[0] == TS_SYNC_BYTE && m_pmt[0] == TS_SYNC_BYTE ) {
		// Start new files with PAT and PMT
		out->write(m_pat, TS_PACKET_SIZE);
		out->write(m_pmt, TS_PACKET_SIZE);
	}	

	signed long long pcr = -1, pcr_segstart_actual = -1;
	while( 1 ) { /* exit loop on break */
		pid_t pid;
		if( m_pkt[0] == TS_SYNC_BYTE ) goto copy_packet; // buffer still contains a packet from previous iteration

		try {
			in->read(m_pkt, TS_PACKET_SIZE);

			if( m_pkt[0] != TS_SYNC_BYTE ) {
				std::cerr << "Lost TS-sync\n";
				return -((pcr - m_pcr_segstart) & 0x1ffffffffLL ) / TS_PCR_FREQ;
			}
		} catch( std::ios_base::failure e ) {
			if( ! in->eof() ) throw;
			return -((pcr - pcr_segstart_actual) & 0x1ffffffffLL ) / TS_PCR_FREQ;
		}

		pid = PID(m_pkt+1); // PID is located after the sync-byte

		
		if( m_pat[0] != TS_SYNC_BYTE ) { // Parse a PAT to find this
			if( pid != 0 ) goto next_packet; // Not a PAT
			if( ! TS_PAYLOAD_UNIT_START(m_pkt) ) goto next_packet; // Table doesn't start here
			char *q = m_pkt + TS_PAYLOAD_START(m_pkt);
			if( *q != 0x00 ) {
				throw std::logic_error("Not implemented: table pointers");
				// Because that probably needs glueing multiple TS-payloads together
			}
			q++;
			// Parse the PAT
			if( PAT_LENGTH(q) != 13 ) {
				throw std::logic_error("Not implemented: Seems to be an MPTS");
			}
			q += 10;
			m_pmt_pid = PID( q );
			std::cerr << "Parsed PAT, using PMT PID " << m_pmt_pid << "\n";
			memcpy(m_pat, m_pkt, TS_PACKET_SIZE); // keep the PAT
			
			goto copy_packet;
		}

		if( m_pmt[0] != TS_SYNC_BYTE ) { // Parse the PMT to find these
			unsigned char length;

			if( pid != m_pmt_pid ) goto next_packet; // Not the PMT
			if( ! TS_PAYLOAD_UNIT_START(m_pkt) ) goto next_packet; // Table doesn't start here
			char *q = m_pkt + TS_PAYLOAD_START(m_pkt);
			if( *q != 0x00 ) {
				throw std::logic_error("Not implemented: SI table-pointers"); //TODO
				// Because that probably needs glueing multiple TS-payloads together
			}
			q++; // skip over pointer
			// Parse the PMT, seek to the elementary PID list
			q++; // skip over table-id
			length = PMT_LENGTH(q) - 9 - 4; // rest of the header and CRC
			q += 9; // Move to the program info length field
			length -= PMT_LENGTH(q); // skip over the program info descriptor
			q += 2 + PMT_LENGTH(q);
			// we are now at the first byte of the ES-list
			std::cerr << "Parsed PMT: media PIDs: ";
			while( length > 0 ) {
				q += 1;
				pid_t es_pid = PID(q);
				q -= 1;	// TODO
				m_media_pids.insert( es_pid );
				if( PMT_ES_TYPE(q) == STREAM_TYPE_VIDEO_H264 ) {
					m_h264_pid = es_pid;
					std::cerr << es_pid << "(h264) ";
				} else {
					std::cerr << es_pid;
				}
				q += 3;
				length -= 3 + 2 + PMT_ES_LENGTH(q);
				q += 2 + PMT_ES_LENGTH(q);
			}
			if( m_media_pids.size() == 0 ) {
				std::cerr << "None found, exiting...\n";
				throw std::logic_error("No media PID's found");
			}
			std::cerr << "\n";

			memcpy(m_pmt, m_pkt, TS_PACKET_SIZE); // keep the PMT

			goto copy_packet;
		}

		if( (m_pkt[3] & 0x20)	// Adaptation field present
		 && m_pkt[4]	// Adaptation field length > 0
		 && m_pkt[5] & 0x10 ) { // PCR present
			pcr = (static_cast<unsigned char>(m_pkt[6]) << 25)
			    | (static_cast<unsigned char>(m_pkt[7]) << 17) 
			    | (static_cast<unsigned char>(m_pkt[8]) << 9)
			    | (static_cast<unsigned char>(m_pkt[9]) << 1)
			    | (static_cast<unsigned char>(m_pkt[10]) >> 7);
		 	if( pcr_segstart_actual == -1 ) {
				pcr_segstart_actual = pcr;
			}
		}

		// Should we switch to the next segment?
		if( ((pcr - m_pcr_segstart) & 0x1ffffffffLL) >= m_pcr_length // Enough seconds
		 && (m_h264_pid == TS_DUMMY_PID || pid == m_h264_pid) // if h264_pid is set, only match on that pid
		 && TS_PAYLOAD_UNIT_START(m_pkt) // start of a new PES
		 ) { // Parse the PES header
			char *q = m_pkt;
			q += TS_PAYLOAD_START(q);
			q += 8;
			q += 1 + *q; // Header length field
			
			// What NAL do we have?
			if( *(q+4) == 0x09 ) q += 6; // NAL is an AUD, skip it

			if( *(q+4) == 0x67 )// NAL is an SPS
				break; // IDR frame, switch now
		}

		// Copy this packet?
		if( pid == 0 ) goto copy_packet;
		if( pid == m_pmt_pid) goto copy_packet;
		if( m_media_pids.find( pid ) != m_media_pids.end() ) goto copy_packet;

		goto next_packet;

	copy_packet:
		out->write(m_pkt, TS_PACKET_SIZE);

	next_packet:
		m_pkt[0] = 0x00; // mark buffer as written
	}

	m_pcr_segstart += m_pcr_length;

	return ((pcr - pcr_segstart_actual) & 0x1ffffffffLL ) / TS_PCR_FREQ;
}

} // namespace

// vim: set ts=4 sw=4:
