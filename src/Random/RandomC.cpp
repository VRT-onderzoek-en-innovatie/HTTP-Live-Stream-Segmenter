#include "RandomC.hpp"
#include <stdlib.h>
#include <time.h>

namespace Random {

RandomC::RandomC(unsigned int seed) {
	if( seed == 0 ) {
		seed = time(NULL);
	}
	srand(seed);
}

char RandomC::Byte() {
	return rand();
}

} // namespace
