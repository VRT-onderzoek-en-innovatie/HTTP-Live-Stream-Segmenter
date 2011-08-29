#ifndef __CRYPTO_H__
#define __CRYPTO_H__

#include <ostream>
#include <sstream>

class Crypto {
protected:
	Crypto() {}
public:
	virtual ~Crypto() {}
	virtual unsigned long blockSize() = 0; // Block size in bytes
	virtual std::string method() = 0; // Method value
	virtual void encrypt(const char *in, char *out) = 0; // encrypts 1 block from in to out
	virtual void decrypt(const char *in, char *out) = 0;
};

class CryptoProxyBuffer : public std::basic_streambuf<char, std::char_traits<char> > {
public:
	CryptoProxyBuffer( std::ostream& output, Crypto *module );
	~CryptoProxyBuffer();

protected:
	virtual int overflow(int c);
	virtual int sync();

private:
	std::ostream& m_output;
	Crypto *m_module;
	char *m_buf;
	unsigned long m_nbuf;
};

class CryptoProxy : public std::basic_ostream<char, std::char_traits<char> > {
private:
	CryptoProxyBuffer m_buf;
public:
	CryptoProxy( std::ostream& output, Crypto *module ) :
		std::basic_ostream<char, std::char_traits<char> >( &m_buf ),
		m_buf( output, module )
		{}
};

#endif
// vim: set ts=4 sw=4:
