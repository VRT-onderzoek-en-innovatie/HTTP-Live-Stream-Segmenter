#include "Timestamp.hpp"
#include <sstream>
#include <assert.h>
#include <stdexcept>

namespace FileArray {

void Timestamp::init(std::string pattern, char wildcard) {
	size_t seq_start = pattern.find_first_of(wildcard);
	if( seq_start == std::string::npos ) {
		std::ostringstream msg;
		msg << "Pattern \"" << pattern << "\" does not contain wildcard character \"" << wildcard << "\"";
		throw std::invalid_argument(msg.str());
	}
	m_prefix = pattern.substr(0, seq_start);

	size_t seq_end = pattern.find_first_not_of(wildcard, seq_start);
	if( seq_end != std::string::npos ) m_suffix = pattern.substr(seq_end);
	
	assert(seq_end > seq_start);
}

std::string Timestamp::Filename(unsigned long seq) {
	time_t now_secs = time(NULL);
	struct tm *now = localtime( &now_secs );
	char date[22]; // enouch to fit 2^64
	int length = strftime(date, sizeof(date), "%s", now);
	std::string timestamp(date, length);

	std::string ret = m_prefix;
	ret += timestamp;
	ret += m_suffix;

	return ret;
}

} // namespace

/* vim: set ts=4 sw=4: */
