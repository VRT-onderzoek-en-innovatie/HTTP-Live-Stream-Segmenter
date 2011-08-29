#include "IndexFile.hpp"

IndexFile::IndexFile(std::string filename, unsigned long target_duration) :
	m_filename(filename),
	m_target_duration(target_duration),
	m_uri_prefix(""),
	m_uri_suffix(""),
	m_key_prefix(""),
	m_key_suffix(""),
	m_sequence(1) {
	m_out.exceptions( std::ifstream::failbit | std::ifstream::badbit );
}

void IndexFile::Begin() {
	m_out.open(m_filename.c_str());
	WriteHeader();
}

void IndexFile::End() {
	WriteEnd();
	m_out.close();
}

void IndexFile::WriteHeader(unsigned long first_sequence) {
	m_out << "#EXTM3U\n"
	      << "#EXT-X-TARGETDURATION:" << m_target_duration << "\n"
	      << "#EXT-X-MEDIA-SEQUENCE:" << first_sequence << "\n";
	m_prev_crypto = "#EXT-X-KEY:METHOD=NONE"; // Default
}

void IndexFile::WriteSegment(struct segment &seg) {
	std::string crypto = "#EXT-X-KEY:METHOD=" + seg.crypto_method;
	if( seg.key_uri != "") crypto += ",URI=\"" 
		+ m_key_prefix + seg.key_uri + m_key_suffix + "\"";

	if( crypto != m_prev_crypto ) {
		m_prev_crypto = crypto;
		m_out << crypto << "\n";
	}

	m_out << "#EXT-X-PROGRAM-DATE-TIME:" << seg.timestamp << "\n"
	      << "#EXTINF:" << seg.duration << ",\n" 
	      << m_uri_prefix << seg.uri << m_uri_suffix << "\n";
}

void IndexFile::WriteEnd() {
	m_out << "#EXT-X-ENDLIST\n";
}

void IndexFile::AddSegment(unsigned long duration, std::string uri, std::string crypto_method, std::string key_uri) {
	m_sequence++;

	time_t now_secs = time(NULL);
	struct tm *now = localtime( &now_secs );
	
	char date[25];
	int length = strftime(date, sizeof(date), "%Y%m%dT%H%M%S%z", now);
	std::string timestamp(date, length);

	struct segment s = { duration, uri, crypto_method, key_uri, timestamp };
	WriteSegment(s);
	m_out.flush();
}
// vim: set ts=4 sw=4:
