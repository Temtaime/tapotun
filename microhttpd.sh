#!/bin/bash
set -eu; trap 'echo "$0 at line $LINENO: exit code is $?" >&2' ERR

DIR=$PWD
DST=$DIR/uhttpd

cd $(mktemp -d)
git clone https://github.com/Karlson2k/libmicrohttpd.git --depth 1
cd libmicrohttpd

rm -rf $DST
mkdir -p $DST/src $DST/include/w32

rm -rf src/microhttpd/test_*
rm -rf src/microhttpd/md5_ext.c
rm -rf src/microhttpd/sha256_ext.c
rm -rf src/microhttpd/connection_https.c

cp src/lib/*.c src/lib/*.h $DST/src
cp src/include/*.h $DST/include
cp w32/common/MHD_config.h $DST/include/w32
cp -r src/microhttpd $DST

cd $DST
rm -rf $OLDPWD

perl -i -pe '$c+=s/(HAVE_MESSAGES) 1/$1 0/g;END{exit(not $c)}' include/w32/MHD_config.h
perl -i -pe '$c+=s/(#include "internal.h")/$1\n#include <io.h>/g;END{exit(not $c)}' src/response_from_fd.c

clang-cl -m64 -fno-stack-protector -O3 -DNDEBUG -msse3 -w -fuse-ld=llvm-lib -o uhttpd.lib src/*.c microhttpd/*.c -I include -I include/w32
