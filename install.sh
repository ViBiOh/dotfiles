#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printTitle() {
  local line='--------------------------------------------------------------------------------'

  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
  printf "%s%s%s\n" "| " "${1}" " |"
  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
}

createSymlinks() {
  for file in "${SCRIPT_DIR}/symlinks"/*; do
    basenameFile=$(basename "${file}")
    [ -r "${file}" ] && [ -e "${file}" ] && rm -f "${HOME}/.${basenameFile}" && ln -s "${file}" "${HOME}/.${basenameFile}"
  done
}

installTools() {
  local LANG=C

  for file in "${SCRIPT_DIR}/install"/*; do
    local basenameFile=$(basename ${file%.*})
    local upperCaseFilename=$(echo "${basenameFile}" | tr '[:lower:]' '[:upper:]')
    local disableVariableName="DOTFILES_NO_${upperCaseFilename}"

    if [[ "${!disableVariableName:-}" == "true" ]]; then
      continue
    fi

    printTitle "${basenameFile}"
    [ -r "${file}" ] && [ -x "${file}" ] && "${file}"
  done
}

cleanPackages() {
  if command -v brew > /dev/null 2>&1; then
    brew cleanup
  elif command -v apt-get > /dev/null 2>&1; then
    sudo apt-get autoremove -y
    sudo apt-get clean all
  fi
}

main() {
  printTitle "symlinks"
  createSymlinks

  set +u
  set +e
  mkdir -p "${HOME}/opt/bin"
  PS1='$' source "${HOME}/.bashrc"
  set -e
  set -u

  printTitle "install"
  installTools

  printTitle "clean"
  cleanPackages

  if command -v subl > /dev/null 2>&1; then
    printTitle "sublime"
    pushd sublime && ./install.sh && popd
  fi
}

main
