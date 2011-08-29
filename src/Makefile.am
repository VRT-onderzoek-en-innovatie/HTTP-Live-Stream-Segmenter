bin_PROGRAMS = ByteCount ADTS MP3 MpegtsH264

common = main.cpp \
         Random/Random.cpp Random/Random.hpp Random/RandomC.cpp Random/RandomC.hpp \
         Crypto/Crypto.cpp Crypto/Crypto.hpp Crypto/CryptoAes128cbc.cpp Crypto/CryptoAes128cbc.hpp \
         IndexFile.cpp IndexFile.hpp IndexFileLive.cpp IndexFileLive.hpp \
         Segmenter/Segmenter.cpp Segmenter/Segmenter.hpp

ByteCount_SOURCES = $(common) \
                    Segmenter/ByteCount.cpp Segmenter/ByteCount.hpp
ByteCount_CPPFLAGS = -DSEGMENTER=ByteCount -include "Segmenter/ByteCount.hpp"

ADTS_SOURCES = $(common) \
               Segmenter/ADTS.cpp Segmenter/ADTS.hpp
ADTS_CPPFLAGS = -DSEGMENTER=ADTS -include "Segmenter/ADTS.hpp"

MP3_SOURCES = $(common) \
              Segmenter/MP3.cpp Segmenter/MP3.hpp
MP3_CPPFLAGS = -DSEGMENTER=MP3 -include "Segmenter/MP3.hpp"

MpegtsH264_SOURCES = $(common) \
                     Segmenter/MpegtsH264.cpp Segmenter/MpegtsH264.hpp
MpegtsH264_CPPFLAGS = -DSEGMENTER=MpegtsH264 -include "Segmenter/MpegtsH264.hpp"
