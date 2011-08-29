#include "Random.hpp"

namespace Random {

void Random::Bytes(char *buf, size_t length) {
	for(size_t i = 0; i < length; i++ ) {
		buf[i] = Byte();
	}
}

} // namespace
