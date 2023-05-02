#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  local DOTFILES_HOSTNAME
  DOTFILES_HOSTNAME="$(hostname)"

  printf '127.0.0.1 local
127.0.0.1 localhost
127.0.0.1 localhost.localdomain
127.0.0.1 %s
255.255.255.255 broadcasthost
::1 ip6-localhost
::1 ip6-loopback
::1 localhost
::1 %s
fe00::0 ip6-localnet
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
' "${DOTFILES_HOSTNAME}" "${DOTFILES_HOSTNAME}" | sudo tee "/etc/hosts" >/dev/null
}
