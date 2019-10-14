#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  local DNSMASQ_CONF="/etc/dnsmasq.conf"
  local LISTEN_ADDRESS="127.0.0.1"

  if command -v brew > /dev/null 2>&1; then
    brew install dnsmasq
    DNSMASQ_CONF="$(brew --prefix)/etc/dnsmasq.conf"
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get install -y -qq dnsmasq
  elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed dnsmasq
  fi

  if ! command -v dnsmasq > /dev/null 2>&1; then
    return
  fi

  echo "listen-address=${LISTEN_ADDRESS}
bind-interfaces

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

  if command -v brew > /dev/null 2>&1; then
    sudo brew services restart dnsmasq
    sudo networksetup -setdnsservers "Wi-Fi" 127.0.0.1

    scutil --dns
    networksetup -getdnsservers "Wi-Fi"
  elif command -v apt-get > /dev/null 2>&1; then
    sudo systemctl restart dnsmasq
  fi
}
