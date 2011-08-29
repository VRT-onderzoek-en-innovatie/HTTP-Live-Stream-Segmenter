#ifndef __RANDOMC_H__
#define __RANDOMC_H__

#include "Random.hpp"

namespace Random {

class RandomC : public Random {
public:
	RandomC(unsigned int seed = 0);

	virtual char Byte();
};

} // namespace

#endif
