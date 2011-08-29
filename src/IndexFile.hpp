#ifndef __INDEXFILE_H__
#define __INDEXFILE_H__

#include <fstream>

class IndexFile {
protected:
	std::string m_filename;
	std::ofstream m_out;
	unsigned long m_target_duration;
	std::string m_uri_prefix, m_uri_suffix;
	std::string m_key_prefix, m_key_suffix;
	unsigned long m_sequence;
	struct segment {
		unsigned long duration;
		std::string uri;
		std::string crypto_method;
		std::string key_uri;
		std::string timestamp;
	};
	std::string m_prev_crypto;

	void WriteHeader(unsigned long first_sequence = 1);
	void WriteSegment(struct segment &seg);
	void WriteEnd();

public:
	IndexFile(std::string filename, unsigned long target_duration);
	virtual ~IndexFile() {}

	void setFilename(std::string filename) { m_filename = filename; }
	std::string Filename() { return m_filename; }

	void setTargetDuration(unsigned long target_duration) { m_target_duration = target_duration; }
	unsigned long TargetDuration() { return m_target_duration; }
	
	void setUriPrefix(std::string prefix) { m_uri_prefix = prefix; }
	std::string UriPrefix() { return m_uri_prefix; }
	
	void setUriSuffix(std::string suffix) { m_uri_suffix = suffix; }
	std::string UriSuffix() { return m_uri_suffix; }

	void setKeyPrefix(std::string prefix) { m_key_prefix = prefix; }
	std::string KeyPrefix() { return m_key_prefix; }
	
	void setKeySuffix(std::string suffix) { m_key_suffix = suffix; }
	std::string KeySuffix() { return m_key_suffix; }
	
	unsigned long Sequence() { return m_sequence; }
	/* Starts at 1 */

	virtual void Begin(); /* Openes file and writes header */
	virtual void AddSegment(unsigned long duration, std::string uri, std::string crypto_method = "NONE", std::string key_uri = "");
	virtual void End(); /* Writes END tag and closes file */
};

#endif
// vim: set ts=4 sw=4:
