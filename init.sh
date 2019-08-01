#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printTitle() {
  local line="--------------------------------------------------------------------------------"

  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
  printf "%s%s%s\n" "| " "${1}" " |"
  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
}

createSymlinks() {
  for file in "${CURRENT_DIR}/symlinks"/*; do
    basenameFile="$(basename "${file}")"
    [[ -r "${file}" ]] && [[ -e "${file}" ]] && rm -f "${HOME}/.${basenameFile}" && ln -s "${file}" "${HOME}/.${basenameFile}"
  done
}

browseInstall() {
  local LANG="C"

  for file in "${CURRENT_DIR}/install"/*; do
    local basenameFile="$(basename ${file%.*})"
    local upperCaseFilename="$(echo "${basenameFile}" | tr "[:lower:]" "[:upper:]")"
    local disableVariableName="DOTFILES_NO_${upperCaseFilename}"

    if [[ "${!disableVariableName:-}" == "true" ]]; then
      continue
    fi

    if [[ -r "${file}" ]]; then
      for action in "${@}"; do
        unset -f "${action}"
      done

      source "${file}"

      for action in "${@}"; do
        if [[ "$(type -t ${action})" = "function" ]]; then
          printTitle "${action} - ${basenameFile}"
          "${action}"
        fi
      done
    fi
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
  local ARGS="${*}"

  if [[ -z "${ARGS}" ]] || [[ "${ARGS}" =~ symlinks ]]; then
    printTitle "symlinks"
    createSymlinks
  fi

  set +u
  set +e
  mkdir -p "${HOME}/opt/bin"
  PS1="$" source "${HOME}/.bashrc"
  set -e
  set -u

  if [[ -z "${ARGS}" ]] || [[ "${ARGS}" =~ install ]]; then
    browseInstall clean install
    cleanPackages
  fi

  if [[ -z "${ARGS}" ]] || [[ "${ARGS}" =~ credentials ]]; then
    browseInstall credentials
  fi

  if [[ "${ARGS}" =~ clean ]]; then
    browseInstall clean
  fi
}

main "${@}"
