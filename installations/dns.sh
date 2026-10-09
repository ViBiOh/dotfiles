#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -f "${HOME}/.unbound-blocklist"
}

install() {
  packages_install "unbound"

  local UNBOUND_CONF_FOLDER="${BREW_PREFIX-}/etc/unbound"
  local UNBOUND_CONF_FILE="${UNBOUND_CONF_FOLDER}/unbound.conf"
  local UNBOUND_CA_CERT="${UNBOUND_CONF_FOLDER}/ca-certificates.pem"
  local UNBOUND_DNSSEC_CERT="${UNBOUND_CONF_FOLDER}/root.key"
  local UNBOUND_BLOCKLIST="${UNBOUND_BLOCKLIST:-${HOME}/.unbound-blocklist}"
  local UNBOUND_PORT="${UNBOUND_PORT:-53}"

  local UNBOUND_INTERFACE_IPV4="127.0.0.1"
  local UNBOUND_INTERFACE_IPV6="::1"
  local UNBOUND_ALL_RULE="refuse"

  if [[ ${UNBOUND_SERVER:-no} == "yes" ]]; then
    UNBOUND_INTERFACE_IPV4="0.0.0.0"
    UNBOUND_INTERFACE_IPV6="::"
    UNBOUND_ALL_RULE="allow"
  fi

  # Default to CloudFlare
  local UNBOUND_FORWARD="${UNBOUND_FORWARD:-
  forward-addr: 2606:4700:4700::1111@853#cloudflare-dns.com
  forward-addr: 1.1.1.1@853#cloudflare-dns.com
  forward-addr: 2606:4700:4700::1001@853#cloudflare-dns.com
  forward-addr: 1.0.0.1@853#cloudflare-dns.com}"

  sudo curl --disable --silent --show-error --location --max-time 30 "https://curl.se/ca/cacert.pem" --output "${UNBOUND_CA_CERT}"
  sudo chmod 600 "${UNBOUND_CA_CERT}"
  sudo chown "root" "${UNBOUND_CA_CERT}"

  echo "server:
  verbosity: 1
  username: root

  interface: ${UNBOUND_INTERFACE_IPV4}
  interface: ${UNBOUND_INTERFACE_IPV6}
  port: ${UNBOUND_PORT}
  num-threads: 4

  access-control: 0.0.0.0/0 ${UNBOUND_ALL_RULE}
  access-control: 127.0.0.0/8 allow

  do-ip4: yes
  do-ip6: yes
  do-udp: yes
  do-tcp: yes

  hide-identity: yes
  hide-version: yes
  harden-glue: yes
  harden-dnssec-stripped: yes
  use-caps-for-id: no

  edns-buffer-size: 1232

  prefetch: yes
  cache-min-ttl: 3600
  cache-max-ttl: 86400

  tls-cert-bundle: \"${UNBOUND_CA_CERT}\"
  auto-trust-anchor-file: \"${UNBOUND_DNSSEC_CERT}\"

  use-syslog: no
  logfile: ${UNBOUND_CONF_FOLDER}/unbound.log
  log-queries: no

  include: \"${UNBOUND_BLOCKLIST}\"
${UNBOUND_EXTRA_SERVER_CONF-}

${UNBOUND_EXTRA_DNS_CONF-}
forward-zone:
  name: \".\"
  forward-ssl-upstream: yes${UNBOUND_FORWARD}" | sudo tee "${UNBOUND_CONF_FILE}" >/dev/null

  dns_block "${UNBOUND_BLOCKLIST}"

  sudo unbound-anchor -a "${UNBOUND_DNSSEC_CERT}"

  if [[ ${UNBOUND_PORT} -ne 53 ]] && command -v systemctl >/dev/null 2>&1; then
    if [[ $(systemctl list-unit-files | grep -c unbound-resolvconf) -ne 0 ]]; then
      sudo systemctl disable unbound-resolvconf.service
      sudo systemctl stop unbound-resolvconf.service
    fi
  fi

  if [[ ${OSTYPE} =~ ^darwin ]] && command -v brew >/dev/null 2>&1; then
    sudo brew services restart "unbound"
  elif command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable "unbound.service"
    sudo systemctl restart "unbound.service"
  fi

  if [[ ${UNBOUND_PORT} -eq 53 ]]; then
    echo "nameserver 127.0.0.1" | sudo tee "/etc/resolv.conf" >/dev/null
    dns_set "127.0.0.1" "::1"
  fi

  if command -v resolvconf >/dev/null 2>&1; then
    if [[ -d /etc/NetworkManager/ ]]; then
      printf -- "dns=none\n" | sudo tee "/etc/NetworkManager/NetworkManager.conf" >/dev/null
    fi

    if [[ ${UNBOUND_PORT} -eq 53 ]]; then
      echo "resolv_conf=/etc/resolv.conf
  nameserver 127.0.0.1
  nameserver ::1" | sudo tee "/etc/resolvconf.conf" >/dev/null
      sudo resolvconf -u
    fi
  fi
}
