#!/bin/sh
set -eu; trap 'echo "$0 at line $LINENO: exit code is $?" >&2' ERR

REPO=https://api.github.com/repos/lexiforest/curl-impersonate/releases/latest

wget -q $(wget -q -O- $REPO | jq -r ".tarball_url") -O - | tar xzf -
cd lexiforest-curl-impersonate-*

patch -p1 -i ../curl/curl.patch

sed "s/SUBJOBS := 4/SUBJOBS := $(grep processor /proc/cpuinfo | wc -l)/" -i Makefile.in

./configure --enable-static
make build

ar -M << EOF
CREATE ../libcurl-impersonate$1.a
$(find . -name '*.a' -exec echo ADDLIB {} \; | grep installed)
$(find ./boringssl-*/lib -name '*.a' -exec echo ADDLIB {} \;)
ADDLIB $(ls ./curl-*/lib/.libs/libcurl-impersonate.a)
ADDLIB /usr/lib/libzstd.a
SAVE
END
EOF
