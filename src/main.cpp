#include <iostream>
#include <sysexits.h>
#include <list>
#include <getopt.h>
#include <sstream>
#include <stdexcept>
#include <assert.h>
#include <math.h>

#include "Segmenter/Segmenter.hpp"
#include "IndexFile.hpp"
#include "IndexFileLive.hpp"
#include "Crypto/CryptoAes128cbc.hpp"
#include "Random/RandomC.hpp"
#include "FileArray/Sequence.hpp"
#include "FileArray/Timestamp.hpp"

int main(int argc, char *argv[]) {
	float duration = 10;
	std::string out_file_pattern("out-?????.ts");
	std::auto_ptr<FileArray::FileArray> out_filenames( new FileArray::Sequence(out_file_pattern, '?') );
	IndexFile *index = new IndexFile("out.m3u8", duration);
	std::string extra_options;
	std::istream *in = &std::cin;
	unsigned long crypto = 0;
	FileArray::Sequence key_filenames("key-????.key", '?');

	static const struct option long_opts[] = {
		/* name, arg, flag, val */
		{"help",        no_argument,            NULL, '?'},
		{"input",       required_argument,      NULL, 'i'},
		{"output",      required_argument,      NULL, 'o'},
		{"out-prefix",  required_argument,      NULL, 'O'},
		{"out-suffix",  required_argument,      NULL, 's'},
		{"length",      required_argument,      NULL, 'l'},
		{"extra",       required_argument,      NULL, 'e'},
		{"index",       required_argument,      NULL, 'I'},
		{"live",        required_argument,      NULL, 'L'},
		{"crypto",      required_argument,      NULL, 'c'},
		{"key",         required_argument,      NULL, 'k'},
		{"key-prefix",  required_argument,      NULL, 'K'},
		{"key-suffix",  required_argument,      NULL, 'S'},
		{"timestamp",   no_argument,            NULL, 't'},
		{NULL, 0, NULL, 0}
	};

	int option;
	while( -1 != (option = getopt_long(argc, argv, "?i:o:O:s:l:e:I:L:c:k:K:S:t", long_opts, NULL)) ) { switch(option) {
    	case '?': /* help */
			std::cerr << "Usage: " << argv[0] << " [options]\n"
			          << "\n"
					  //  <-------- --------- --------- -- 80 chars wide -- --------- --------- --------->
					  << "Options are:\n"
					  << "  -i --input s       Source file, default stdin.\n"
					  << "  -o --output s      Destination pattern. '?' are replaced with a sequence\n"
					  << "                     default \"out-?????.ts\"\n"
					  << "  -t --timestamp     Fill in pattern with current timestamp instead of sequence\n"
					  << "                     Probably only useful in Live-mode (see below)\n"
					  << "  -O --out-prefix s  Prefix to add to every output filename in the index\n"
					  << "  -s --out-suffix s  Suffix to add to every output filename in the index\n"
					  << "  -l --length s      Size of each segment, default 10\n"
					  << "                     Must start with the average duration in seconds\n"
					  << "                     The rest of the argument is passed to the segmenting\n"
					  << "                     module as-is and may contain extra settings\n"
					  << "  -e --extra s       Extra parameters, see below\n"
					  << "  -I --index s       Index list file, default \"out.m3u8\"\n"
					  << "  -L --live i        Specifies how many segments to put in the live playlist\n"
					  << "                     You probably want to set -i to a pipe to use this\n"
					  << "  -c --crypto i      Encrypt the output segments; switch keys every specified\n"
					  << "                     number of segments\n"
					  << "  -k --key s         Key pattern. '?' are replaced with a secuence number\n"
					  << "                     default \"key-?????.key\"\n"
					  << "  -K --key-prefix s  Prefix to add to every key filename in the index\n"
					  << "  -S --key-suffix s  Suffix to add to every key filename in the index\n"
					  << "\n",
			Segmenter::SEGMENTER::usage();
			exit(EX_USAGE);
			break; // will never be reached

		case 'i': /* input */
			std::cerr << "Opening input file \"" << optarg << "\"\n";
			in = new std::ifstream(optarg);
			break;
			
		case 'o': /* output */
			out_file_pattern.assign(optarg);
			out_filenames->init(out_file_pattern, '?');
			break;
		case 'O': /* out-prefix */
			index->setUriPrefix(optarg);
			break;
		case 's': /* out-suffix */
			index->setUriSuffix(optarg);
			break;


		case 'l': /* length */
			char *tmp;
			duration = strtol(optarg, &tmp, 10);
			if( tmp == optarg ) {
				std::cerr << "Invalid integer for length parameter \"" << optarg << "\"\n";
				exit(EX_USAGE);
			}
			index->setTargetDuration(duration);
			break;

		case 'e':
			extra_options = optarg;
			break;

		case 'I': /* index */
			index->setFilename(optarg);
			break;

		case 'L': /* live */
			{
				unsigned long live = strtol(optarg, &tmp, 10);
				if( tmp == optarg ) {
					std::cerr << "Invalid integer for live parameter \"" << optarg << "\"\n";
					exit(EX_USAGE);
				}
				IndexFile *tmp_idx = new IndexFileLive( index->Filename(), index->TargetDuration(), live, true);
				delete index;
				index = tmp_idx;
			}
			break;

		case 'c': /* crypto */
			crypto = strtol(optarg, &tmp, 10);
			if( tmp == optarg ) {
				std::cerr << "Invalid integer for crypto parameter \"" << optarg << "\"\n";
				exit(EX_USAGE);
			}
			break;

		case 'k': /* key */
			key_filenames.init(optarg, '?');
			break;
		case 'K': /* key-prefix */
			index->setKeyPrefix(optarg);
			break;
		case 'S': /* key-suffix */
			index->setKeySuffix(optarg);
			break;

		case 't': /* timestamp */
			out_filenames.reset( new FileArray::Timestamp(out_file_pattern ,'?') );
			break;
	}}


	in->exceptions( std::ifstream::eofbit | std::ifstream::failbit | std::ifstream::badbit );
	Segmenter::SEGMENTER seg(duration, extra_options);
	index->Begin();
	char key[16];
	std::string key_filename;
	Random::RandomC rnd; // TODO: better random generator
	float duration_acc_error = 0;
	do {
		std::ofstream out_file;
		out_file.exceptions( std::ofstream::failbit | std::ofstream::badbit );
		std::string out_filename = out_filenames->Filename( index->Sequence() );
		out_file.open(out_filename.c_str());
		std::cerr << "Switching to file \"" << out_filename << "\"  ";

		if( crypto && index->Sequence() % crypto == 1 ) {
			// Switch Crypto key
			rnd.Bytes(key, 16);
			key_filename = key_filenames.Filename( index->Sequence() );
			std::cerr << "New crypto file \"" << key_filename << "\"\n";
			std::ofstream key_file;
			key_file.exceptions( std::ofstream::failbit | std::ofstream::badbit );
			key_file.open( key_filename.c_str() );
			key_file.write(key, 16);
			key_file.close();
		}

		std::ostream *out = &out_file;
		Crypto::Crypto *crypto_module = NULL;
		if( crypto ) {
			char iv[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
			for(unsigned char i=0; i < 4; i++ ) iv[15-i] = index->Sequence() >> (8*i);
			crypto_module = new CryptoAes128cbc(key, iv);
			out = new CryptoProxy(out_file, crypto_module);
		}

		duration = seg.copy_segment(in, out);
		int rounded_duration = round(abs(duration) + duration_acc_error);
		duration_acc_error += duration - rounded_duration;
		if( duration <= 0 ) rounded_duration += 1; // Workaround bug in Safari plugin
		
		*out << std::flush;
		out_file.close();
		std::cerr << duration << "secs\n";

		if( crypto ) {
			index->AddSegment(rounded_duration, out_filename, crypto_module->method(), key_filename);
			delete out;
		} else {
			index->AddSegment(rounded_duration, out_filename);
		}
	} while( duration > 0 );
	index->End();

	return EX_OK;
}

/* vim: set ts=4 sw=4: */
