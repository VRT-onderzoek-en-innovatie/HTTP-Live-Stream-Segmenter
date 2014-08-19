#include "Crypto.hpp"
#include <iostream>
#include <stdexcept>

CryptoProxyBuffer::CryptoProxyBuffer( std::ostream& output, Crypto *module ) :
	m_output( output ),
	m_module( module ),
	m_nbuf( 0 ) {
	m_buf = new char[ m_module->blockSize() ];
}

CryptoProxyBuffer::~CryptoProxyBuffer() {
	delete m_buf;
}

int CryptoProxyBuffer::overflow(int c) {
	m_buf[ m_nbuf++ ] = static_cast<char>(c);

	if( m_nbuf == m_module->blockSize() ) {
		m_nbuf = 0;
		char *crypt_buf = new char[ m_module->blockSize() ];
		m_module->encrypt(m_buf, crypt_buf);
		m_output.write(crypt_buf, m_module->blockSize() );
		delete crypt_buf;
	}

	return std::char_traits<char>::not_eof(c);
}

int CryptoProxyBuffer::sync() {
	// add PKCS7 padding
	unsigned char pad = m_module->blockSize() - m_nbuf;
	for( unsigned char i = 0; i < pad; i++ ) {
		overflow(pad);
	}
	m_output << std::flush;
	return 0;
}

// vim: set ts=4 sw=4:
