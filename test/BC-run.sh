#!/bin/bash

set -e # exit immediately

dd if=/dev/zero bs=100 count=10 | ../src/ByteCount -e 100 -l 2

if [ ! -e "out-00001.ts" ] ||
	[ ! -e "out-00002.ts" ] ||
	[ ! -e "out-00003.ts" ] ||
	[ ! -e "out-00004.ts" ] ||
	[ ! -e "out-00005.ts" ]; then
		echo "Did not find 5 output files"
		exit 1
fi

dd if=/dev/zero bs=100 count=2 of=ref

diff ref out-00001.ts
diff ref out-00002.ts
diff ref out-00003.ts
diff ref out-00004.ts
diff ref out-00005.ts

rm out-0000{1,2,3,4,5,6}.ts out.m3u8 ref
