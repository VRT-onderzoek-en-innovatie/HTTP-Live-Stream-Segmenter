#ifndef __CRYPTAES128CBC_H__
#define __CRYPTAES128CBC_H__

#include "Crypto.hpp"
#include <openssl/aes.h>

class CryptoAes128cbc: public Crypto {
	unsigned char m_iv[16];
	AES_KEY m_key;
public:
	CryptoAes128cbc(char key[16], char iv[16]);
	virtual ~CryptoAes128cbc();
	virtual unsigned long blockSize() { return 16; } // Block size in bytes
	virtual std::string method() { return "AES-128"; }
	virtual void encrypt(const char *in, char *out); // encrypts 1 block from in to out
	virtual void decrypt(const char *in, char *out);
};

#endif
