#include "IndexFileLive.hpp"

IndexFileLive::IndexFileLive(std::string filename, unsigned long target_duration, unsigned long num_segments, bool unlink) :
	IndexFile(filename, target_duration),
	m_num_segments(num_segments),
	m_unlink(unlink) {
	m_temp_filename = filename + ".tmp";
}

void IndexFileLive::Begin() {
	/* Empty */
}

void IndexFileLive::AddSegment(unsigned long duration, std::string uri, std::string crypto_method, std::string key_uri) {
	m_sequence++;
	time_t now_secs = time(NULL);
	struct tm *now = localtime( &now_secs );
	
	char date[25];
	int length = strftime(date, sizeof(date), "%Y%m%dT%H%M%S%z", now);
	std::string timestamp(date, length);

	struct segment s = { duration, uri, crypto_method, key_uri, timestamp };

	m_segments.push_back(s);
	while( m_segments.size() > m_num_segments ) {
		if( m_unlink ) {
			unlink( m_segments.begin()->uri.c_str() );
		}
		m_segments.pop_front();
	}

	m_out.open( m_temp_filename.c_str() );

	WriteHeader(m_sequence - m_segments.size());
	for( typeof(m_segments.begin()) i = m_segments.begin(); i != m_segments.end(); i++ ) {
		WriteSegment(*i);
	}

	m_out.close();
	if( rename(m_temp_filename.c_str(), m_filename.c_str() ) ) {
		throw std::ios_base::failure("Could not rename Index file");
	}
}
