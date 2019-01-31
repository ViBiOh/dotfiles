#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sed_inplace() {
  if [[ "${IS_MACOS}" == true ]]; then
    sed -i '' "${@}"
  else
    sed -i "${@}"
  fi
}

main() {
  if command -v pihole > /dev/null 2>&1; then
    echo "pihole found, no action"
    exit
  fi

  local DNSMASQ_CONF='/etc/dnsmasq.conf'

  if [[ "${IS_MACOS}" == true ]]; then
    brew install dnsmasq --with-dnssec
    brew install dnscrypt-proxy
    DNSMASQ_CONF=$(brew --prefix)/etc/dnsmasq.conf

    if [[ -e "$(brew --prefix)/etc/dnscrypt-proxy.toml" ]]; then
      sed_inplace "s|^listen_addresses.*$|listen_addresses = ['127.0.0.1:5355']|g" /Users/macbook/homebrew/etc/dnscrypt-proxy.toml
    fi
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq dnsmasq
  fi

  echo "listen-address=$(hostname -I || '127.0.0.1')
bind-interfaces

# Forward queries to DNSCrypt on localhost port 5355
server=127.0.0.1#5355
server=1.1.1.1
server=1.0.0.1

# Never forward plain (local) names
domain-needed

# Never forward addresses in the non-routed address spaces
bogus-priv

# Reject private addresses from upstream nameservers
stop-dns-rebind
rebind-localhost-ok

# Query servers in order
strict-order

# Set the size of the cache
# The default is to keep 150 hostnames
cache-size=8192

# Optional logging directives
log-async
log-dhcp
log-facility=/var/log/dnsmasq.log" | sudo tee "${DNSMASQ_CONF}" > /dev/null

  if [[ "${IS_MACOS}" == true ]]; then
    sudo brew services restart dnscrypt-proxy
    sudo brew services restart dnsmasq
    sudo networksetup -setdnsservers "Wi-Fi" 127.0.0.1
    scutil --dns
    networksetup -getdnsservers "Wi-Fi"
  elif command -v apt-get > /dev/null 2>&1; then
    sudo systemctl restart dnsmasq
  fi
}

main
