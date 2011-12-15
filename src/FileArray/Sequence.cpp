#include "Sequence.hpp"
#include <sstream>
#include <assert.h>
#include <stdexcept>

namespace FileArray {

void Sequence::init(std::string pattern, char wildcard) {
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

	m_digits = seq_end - seq_start;
}

std::string Sequence::Filename(unsigned long seq) {
	static const char hex[] = {'0', '1', '2', '3', '4', '5', '6', '7',
							   '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
	std::string ret = m_prefix;
	for( typeof(m_digits) i = m_digits; i > 0; i-- ) {
		ret += hex[ seq >> (i-1)*4 & 0x0f ];
	}
	ret += m_suffix;
	return ret;
}

} // namespace

/* vim: set ts=4 sw=4: */
