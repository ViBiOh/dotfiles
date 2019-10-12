#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_title() {
  local line="--------------------------------------------------------------------------------"

  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
  printf "%s%s%s\n" "| " "${1}" " |"
  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
}

create_symlinks() {
  for file in "${CURRENT_DIR}/symlinks"/*; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file}")"
    [[ -r "${file}" ]] && [[ -e "${file}" ]] && rm -f "${HOME}/.${BASENAME_FILE}" && ln -s "${file}" "${HOME}/.${BASENAME_FILE}"
  done
}

browse_install() {
  local LANG="C"

  for file in "${CURRENT_DIR}/install"/*; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file%.*}")"
    local UPPERCASE_FILENAME
    UPPERCASE_FILENAME="$(echo "${BASENAME_FILE}" | tr "[:lower:]" "[:upper:]")"
    local DISABLE_VARIABLE_NAME="DOTFILES_NO_${UPPERCASE_FILENAME}"

    if [[ "${!DISABLE_VARIABLE_NAME:-}" == "true" ]]; then
      continue
    fi

    if [[ -r "${file}" ]]; then
      for action in "${@}"; do
        unset -f "${action}"
      done

      source "${file}"

      for action in "${@}"; do
        if [[ "$(type -t "${action}")" = "function" ]]; then
          print_title "${action} - ${BASENAME_FILE}"
          "${action}"
        fi
      done
    fi
  done
}

clean_packages() {
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
    print_title "symlinks"
    create_symlinks
  fi

  set +u
  set +e
  mkdir -p "${HOME}/opt/bin"
  PS1="$" source "${HOME}/.bashrc"
  set -e
  set -u

  if [[ -z "${ARGS}" ]] || [[ "${ARGS}" =~ install ]]; then
    browse_install clean install
    clean_packages
  fi

  if [[ -z "${ARGS}" ]] || [[ "${ARGS}" =~ credentials ]]; then
    browse_install credentials
  fi

  if [[ "${ARGS}" =~ clean ]]; then
    browse_install clean
  fi
}

main "${@:-}"
