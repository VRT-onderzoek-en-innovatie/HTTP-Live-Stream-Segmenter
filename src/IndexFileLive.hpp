#ifndef __INDEXFILELIVE_H__
#define __INDEXFILELIVE_H__

#include "IndexFile.hpp"
#include <list>

class IndexFileLive: public IndexFile {
protected:
	unsigned long m_num_segments;
	bool m_unlink;
	std::list<struct segment> m_segments;
	std::string m_temp_filename;

public:
	IndexFileLive(std::string filename, unsigned long target_duration, unsigned long num_segments, bool unlink = false);
	//virtual ~IndexFileLive() {}

	virtual void Begin();
	virtual void AddSegment(unsigned long duration, std::string uri, std::string crypto_method = "NONE", std::string key_uri = "");
	virtual void End();
};

#endif
