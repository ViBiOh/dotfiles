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
  local UNBOUND_CONTROL="${UNBOUND_CONTROL:-yes}"

  # Default to CloudFlare
  local UNBOUND_FORWARD="${UNBOUND_FORWARD:-
  forward-addr: 2606:4700:4700::1111@853#cloudflare-dns.com
  forward-addr: 1.1.1.1@853#cloudflare-dns.com
  forward-addr: 2606:4700:4700::1001@853#cloudflare-dns.com
  forward-addr: 1.0.0.1@853#cloudflare-dns.com
}"

  sudo curl --disable --silent --show-error --location --max-time 30 "https://curl.se/ca/cacert.pem" --output "${UNBOUND_CA_CERT}"
  sudo chmod 600 "${UNBOUND_CA_CERT}"
  sudo chown "root" "${UNBOUND_CA_CERT}"

  echo "server:
  verbosity: 1
  username: root
  chroot: \"\"

  interface: 127.0.0.1
  interface: ::1
  port: ${UNBOUND_PORT}
  num-threads: 4

  access-control: 0.0.0.0/0 refuse
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
  logfile: /var/log/unbound.log
  log-queries: no

  include: \"${UNBOUND_BLOCKLIST}\"
${UNBOUND_EXTRA_SERVER_CONF-}
remote-control:
  control-enable: ${UNBOUND_CONTROL}
  control-interface: 127.0.0.1
  server-key-file: \"${UNBOUND_CONF_FOLDER}/unbound_server.key\"
  server-cert-file: \"${UNBOUND_CONF_FOLDER}/unbound_server.pem\"
  control-key-file: \"${UNBOUND_CONF_FOLDER}/unbound_control.key\"
  control-cert-file: \"${UNBOUND_CONF_FOLDER}/unbound_control.pem\"
${UNBOUND_EXTRA_DNS_CONF-}
forward-zone:
  name: \".\"
  forward-ssl-upstream: yes${UNBOUND_FORWARD}
" | sudo tee "${UNBOUND_CONF_FILE}" >/dev/null

  dns_block "${UNBOUND_BLOCKLIST}"

  sudo unbound-anchor -a "${UNBOUND_DNSSEC_CERT}"

  if [[ ${UNBOUND_CONTROL} == "yes" ]]; then
    if ! [[ -e "${UNBOUND_CONF_FOLDER}/unbound_server.key" ]]; then
      sudo unbound-control-setup -d "${UNBOUND_CONF_FOLDER}"
    fi

    sudo unbound-control -c "${UNBOUND_CONF_FILE}" -q reload || true
    sudo unbound-control -c "${UNBOUND_CONF_FILE}" -q stop || true

    printf -- "Waiting 1 second before starting unbound...\n"
    sleep 1

    sudo unbound-control -c "${UNBOUND_CONF_FILE}" -q start
  fi

  if [[ ${UNBOUND_PORT} -eq 53 ]]; then
    echo "nameserver 127.0.0.1" | sudo tee "/etc/resolv.conf" >/dev/null
  else
    if [[ $(systemctl list-unit-files | grep -c unbound-resolvconf) -ne 0 ]]; then
      sudo systemctl disable unbound-resolvconf.service
      sudo systemctl stop unbound-resolvconf.service
    fi
  fi

  if [[ ${UNBOUND_PORT} -eq 53 ]]; then
    dns_set "127.0.0.1" "::1"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable "unbound.service"
    sudo systemctl restart "unbound.service"
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
