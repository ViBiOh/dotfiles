#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  if ! command -v pass > /dev/null 2>&1; then
    exit
  fi

  local PASS_DIR=${PASSWORD_STORE_DIR-~/.password-store}
  local SCALEWAY_PASS=$(find "${PASS_DIR}" -name '*scaleway.gpg' -print | sed -e "s|${PASS_DIR}/\(.*\)\.gpg$|\1|")

  if [[ $(echo "${SCALEWAY_PASS}" | wc -l) -eq 1 ]]; then
    local SCALEWAY_APPLICATION=$(pass show "${SCALEWAY_PASS}" | grep application | awk '{print $2}')
    local SCALEWAY_TOKEN=$(pass show "${SCALEWAY_PASS}" | grep token | awk '{print $2}')

    echo "{
  \"application\": \"${SCALEWAY_APPLICATION}\",
  \"token\": \"${SCALEWAY_TOKEN}\"
}" > "${HOME}/.scwrc"
  fi
}

main
