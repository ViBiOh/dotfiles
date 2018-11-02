#!/usr/bin/env bash

set -e
set -u

echo "-----------"
echo "- dnsmasq -"
echo "-----------"

if [ `uname` == 'Darwin' ]; then
  brew install dnsmasq --with-dnssec

  echo > `brew --prefix`/etc/dnsmasq.conf << EOF
# Forward queries to DNSCrypt on localhost port 5355
server=127.0.0.1#5355

# Uncomment to forward queries to Google Public DNS, if DNSCrypt is not used
# You may also use your own DNS server or other public DNS server you trust
server=8.8.8.8
server=8.8.4.4

# Never forward plain (local) names
domain-needed

# Never forward addresses in the non-routed address spaces
bogus-priv

# Reject private addresses from upstream nameservers
stop-dns-rebind

# Query servers in order
strict-order

# Set the size of the cache
# The default is to keep 150 hostnames
cache-size=8192

# Optional logging directives
log-async
log-dhcp
log-facility=/var/log/dnsmasq.log
EOF

  sudo brew services start dnsmasq
  sudo networksetup -setdnsservers "Wi-Fi" 127.0.0.1
  scutil --dns
  networksetup -getdnsservers "Wi-Fi"
fi
