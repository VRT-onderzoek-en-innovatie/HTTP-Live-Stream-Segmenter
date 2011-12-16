#ifndef __TIMESTAMP_HPP__
#define __TIMESTAMP_HPP__

#include "FileArray.hpp"

namespace FileArray {

class Timestamp : public FileArray {
protected:
	std::string m_prefix, m_suffix;

public:
	void init(std::string pattern, char wildcard);

	Timestamp(std::string pattern, char wildcard) { init(pattern, wildcard); }

	virtual std::string Filename(unsigned long seq);
};

}

#endif // __TIMESTAMP_HPP__
