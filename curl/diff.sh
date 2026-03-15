#!/bin/bash

diff -rub a b > curl.patch

#   --without-zlib          disable use of zlib
#   --without-brotli        disable BROTLI
#   --without-zstd          disable libzstd
#   --disable-ftp           Disable FTP support
#   --disable-file          Disable FILE support
#   --disable-ipfs          Disable IPFS support
#   --disable-ldap          Disable LDAP support
#   --disable-ldaps         Disable LDAPS support
#   --disable-rtsp          Disable RTSP support
#   --disable-proxy         Disable proxy support
#   --disable-dict          Disable DICT support
#   --disable-telnet        Disable TELNET support
#   --disable-tftp          Disable TFTP support
#   --disable-pop3          Disable POP3 support
#   --disable-imap          Disable IMAP support
#   --disable-smb           Disable SMB/CIFS support
#   --disable-smtp          Disable SMTP support
#   --disable-gopher        Disable Gopher support
#   --disable-mqtt          Disable MQTT support
#   --disable-manual        Disable built-in manual
#   --disable-docs          Disable documentation
#   --disable-ipv6          Disable IPv6 support
