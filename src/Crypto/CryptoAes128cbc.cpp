#include "CryptoAes128cbc.hpp"
#include <string.h>

CryptoAes128cbc::CryptoAes128cbc(char key[16], char iv[16]) {
	memcpy(m_iv, iv, 16);
	AES_set_encrypt_key( reinterpret_cast<unsigned char*>(key), 16*8, &m_key);
}

CryptoAes128cbc::~CryptoAes128cbc() {
}

void CryptoAes128cbc::encrypt(const char *in, char *out) {
	AES_cbc_encrypt( reinterpret_cast<const unsigned char*>(in),
	                 reinterpret_cast<unsigned char*>(out),
	                 this->blockSize(),
	                 &m_key,
	                 m_iv,
	                 AES_ENCRYPT);
}

void CryptoAes128cbc::decrypt(const char *in, char *out) {
	AES_cbc_encrypt( reinterpret_cast<const unsigned char*>(in),
	                 reinterpret_cast<unsigned char*>(out),
	                 this->blockSize(),
	                 &m_key,
	                 m_iv,
	                 AES_DECRYPT);
}
