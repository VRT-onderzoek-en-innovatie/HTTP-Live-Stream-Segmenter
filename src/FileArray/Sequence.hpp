#ifndef __SEQUENCE_HPP__
#define __SEQUENCE_HPP__

#include "FileArray.hpp"

namespace FileArray {

class Sequence : public FileArray {
protected:
	std::string m_prefix, m_suffix;
	unsigned short m_digits;

public:
	void init(std::string pattern, char wildcard);

	Sequence(std::string pattern, char wildcard) { init(pattern, wildcard); }

	virtual std::string Filename(unsigned long seq);
};

}

#endif // __SEQUENCE_HPP__
