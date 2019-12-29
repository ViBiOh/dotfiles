#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_title() {
  local line="--------------------------------------------------------------------------------"

  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
  printf "%s%s%s\n" "| " "${1}" " |"
  printf "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
}

usage() {
    printf "Usage of %s\n" "${0}"
    printf "symlinks\n"
    printf "\t Create symlink of dotfiles into \${HOME}\n"
    printf "clean\n"
    printf "\t Clean installation and temporary files\n"
    printf "install\n"
    printf "\t Install required softwares\n"
    printf "credentials\n"
    printf "\t Extract credentials into dotfiles in \${HOME}\n"
    printf "[blank]\n"
    printf "\t Run all stages\n"
    printf "help\n"
    printf "\t Print this help\n"
}

create_symlinks() {
  for file in "${CURRENT_DIR}/symlinks"/*; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file}")"

    if [[ -n ${FILE_LIMIT} ]] && [[ ${BASENAME_FILE} != "${FILE_LIMIT}" ]]; then
      continue
    fi

    [[ -r ${file} ]] && [[ -e ${file} ]] && rm -f "${HOME}/.${BASENAME_FILE}" && ln -s "${file}" "${HOME}/.${BASENAME_FILE}"
  done
}

browse_install() {
  local LC_ALL="C"
  local LANG="C"

  for file in "${CURRENT_DIR}/install"/*; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file%.*}")"

    if [[ -n ${FILE_LIMIT} ]] && [[ ${BASENAME_FILE} != "${FILE_LIMIT}" ]]; then
      continue
    fi

    local UPPERCASE_FILENAME
    UPPERCASE_FILENAME="$(echo "${BASENAME_FILE}" | tr "[:lower:]" "[:upper:]")"
    local DISABLE_VARIABLE_NAME="DOTFILES_NO_${UPPERCASE_FILENAME}"

    if [[ ${!DISABLE_VARIABLE_NAME:-} == "true" ]]; then
      continue
    fi

    if [[ -r ${file} ]]; then
      for action in "${@}"; do
        unset -f "${action}"
      done

      source "${file}"

      for action in "${@}"; do
        if [[ $(type -t "${action}") = "function" ]]; then
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
  local FILE_LIMIT=""
  while getopts "l:" options; do
    case "${options}" in
      l)
        FILE_LIMIT="${OPTARG}"
        printf "Limiting to %s\n" "${FILE_LIMIT}"
        ;;
      \?)
        printf "unknown option %s\n" "${options}"
        ;;
    esac
  done

  shift $(( OPTIND - 1 ))

  local ARGS="${*}"
  if [[ ${ARGS} =~ help ]]; then
    usage
    return 1
  fi

  if [[ -z ${ARGS} ]] || [[ ${ARGS} =~ symlinks ]]; then
    print_title "symlinks"
    create_symlinks
  fi

  set +u
  set +e
  mkdir -p "${HOME}/opt/bin"
  PS1="$" source "${HOME}/.bashrc"
  set -e
  set -u

  if [[ -z ${ARGS} ]] || [[ ${ARGS} =~ clean ]]; then
    browse_install clean
    clean_packages
  fi

  if [[ -z ${ARGS} ]] || [[ ${ARGS} =~ install ]]; then
    browse_install install
    clean_packages
  fi

  if [[ -z ${ARGS} ]] || [[ ${ARGS} =~ credentials ]]; then
    browse_install credentials
  fi
}

main "${@:-}"
