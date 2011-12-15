#ifndef __FILEARRAY_HPP__
#define __FILEARRAY_HPP__

namespace FileArray {

class FileArray {
protected:
	FileArray() {}

public:
	virtual std::string Filename(unsigned long seq) =0;
};

} // namespace

#endif // __FILEARRAY_HPP__
/* vim: set ts=4 sw=4: */
