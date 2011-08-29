#ifndef __RANDOM_H__
#define __RANDOM_H__

#include <stdlib.h>

namespace Random {

class Random {
protected:
	Random() {}
public:
	virtual char Byte() = 0;

	virtual void Bytes(char *buf, size_t length);
};

} // namespace

#endif
