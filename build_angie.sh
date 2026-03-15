#!/bin/sh
set -eux; trap 'echo "$0 at line $LINENO: exit code is $?" >&2' ERR

P=/workshop/angie

wget -q https://git.angie.software/web-server/angie/archive/Angie-1.11.3.zip
unzip Angie* > /dev/null

wget -q -O- https://github.com/openssl/openssl/releases/download/openssl-3.6.1/openssl-3.6.1.tar.gz | tar xzf -

cd angie
apk add pcre2-dev pcre2-static #openssl-dev openssl-libs-static

./configure													\
			--prefix=$P										\
			--pid-path=/run/angie.pid						\
			--sbin-path=$P/angie							\
			--conf-path=$P/angie.conf						\
			--http-acme-client-path=$P/acme					\
\
			--http-scgi-temp-path=/tmp/angie_scgi_temp					\
			--http-uwsgi-temp-path=/tmp/angie_uwsgi_temp				\
			--http-fastcgi-temp-path=/tmp/angie_fastcgi_temp			\
			--http-proxy-temp-path=/tmp/angie_proxy_temp				\
			--http-client-body-temp-path=/tmp/angie_client_body_temp	\
\
			--error-log-path=stderr							\
			--http-log-path=/dev/stdout						\
\
			--with-http_ssl_module							\
			--with-http_v2_module							\
			--with-http_v3_module							\
			--with-http_acme_module							\
			--without-http_gzip_module						\
\
			--with-openssl=$(echo ../openssl-*)				\
			--with-openssl-opt="no-tests no-shared"			\
\
			--with-ld-opt="-static -flto=full"

make -j$(grep processor /proc/cpuinfo | wc -l)
