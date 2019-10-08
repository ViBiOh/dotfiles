#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

github_last_release() {
  if [[ "${#}" -ne 1 ]]; then
    echo "Usage: github_last_release owner/repo"
    return 1
  fi

  local RED="\033[31m"
  local RESET="\033[0m"

  local OUTPUT_TXT="output.txt"
  local CLIENT_ARGS=("curl" "-q" "-sS" "-o" "${OUTPUT_TXT}" "-w" "%{http_code}")

  local LATEST_RELEASE="$(curl -q -sS -o "${OUTPUT_TXT}" -w "%{http_code}" "https://api.github.com/repos/${1}/releases/latest")"
  if [[ "${LATEST_RELEASE}" != "200" ]]; then
    echo -e "${RED}Unable to list latest release for ${1}${RESET}"
    cat "${OUTPUT_TXT}" && rm "${OUTPUT_TXT}"
    return
  fi

  python -c "import json; print(json.load(open('${OUTPUT_TXT}'))['tag_name'])"
  rm "${OUTPUT_TXT}"
}

rg "CTOP_VERSION=" install/
github_last_release bcicen/ctop

rg "SYNCTHING_VERSION=" install/
github_last_release syncthing/syncthing

rg "TERRAFORM_VERSION=" install/
github_last_release hashicorp/terraform
