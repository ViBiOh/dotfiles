#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit
readonly CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_title() {
  local line="--------------------------------------------------------------------------------"

  printf -- "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
  printf -- "%s%s%s\n" "| " "${1}" " |"
  printf -- "%s%s%s\n" "+-" "${line:0:${#1}}" "-+"
}

usage() {
  printf -- "Usage: %s [flags]\n" "${0}"
  printf -- "  -a\tRun all stages: symlinks, clean, install and passwords\n"
  printf -- "  -c\tClean install and temporary files\n"
  printf -- "  -d\tRecreate dotfilesrc\n"
  printf -- "  -i\tInstall and configure softwares\n"
  printf -- "  -l\tLimiting execution to given filename\n"
  printf -- "  -p\tRetrieve and write credentials\n"
  printf -- "  -s\tCreate symlinks into \${HOME}\n"
  printf -- "  -h\tPrint this help\n"
}

create_symlinks() {
  while IFS= read -r -d '' file; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file}")"

    [[ -r ${file} ]] && [[ -e ${file} ]] && rm -f "${HOME}/.${BASENAME_FILE}" && ln -s "${file}" "${HOME}/.${BASENAME_FILE}"
  done < <(find "${CURRENT_DIR}/symlinks" -type f -print0)
}

do_action() {
  local ACTION_FILENAME="${1}"
  shift

  for action in "${@}"; do
    unset -f "${action}"
  done

  source "${CURRENT_DIR}/installations/${ACTION_FILENAME}"

  for action in "${@}"; do
    if [[ $(type -t "${action}") == "function" ]]; then
      print_title "${action} - ${ACTION_FILENAME}"
      "${action}"
    fi
  done
}

do_mandatory_actions() {
  do_action "__default.sh" "${@}"
  do_action "__fzf.sh" "${@}"
}

create_dotfilesrc() {
  printf -- "Select files to install\n"

  cat >"${HOME}/.dotfilesrc" <<END_OF_DOTFILES_RC
#!/usr/bin/env bash

END_OF_DOTFILES_RC

  while IFS= read -r -d '' file; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file}")"

    local INSTALL_NAME
    INSTALL_NAME="$(printf -- "%s" "${BASENAME_FILE%.sh}" | tr "[:lower:]" "[:upper:]")"

    echo "export DOTFILES_${INSTALL_NAME}=\"true\"" >>"${HOME}/.dotfilesrc"
  done < <(find "${CURRENT_DIR}/installations" -not -name "__*" -type f | LC_ALL=C sort | fzf --multi --print0 --preview 'cat {}')
}

browse_actions() {
  if [[ ${DOTFILES_RC} -ne 1 ]] && [[ -z ${FILE_LIMIT:-} ]]; then
    do_mandatory_actions "${@}"
  fi

  local FILE_TO_INSTALL=()

  while IFS= read -r -d '' file; do
    local BASENAME_FILE
    BASENAME_FILE="$(basename "${file}")"

    local INSTALL_NAME
    INSTALL_NAME="$(printf -- "%s" "${BASENAME_FILE%.sh}" | tr "[:lower:]" "[:upper:]")"

    if [[ -n ${FILE_LIMIT} ]] && [[ ${INSTALL_NAME} != "${FILE_LIMIT}" ]]; then
      continue
    fi

    if [[ ${FILE_RESTART} -eq 1 ]]; then
      FILE_LIMIT=""
    fi

    local ENABLE_VARIABLE_NAME="DOTFILES_${INSTALL_NAME}"

    if [[ ${!ENABLE_VARIABLE_NAME:-} != "true" ]]; then
      continue
    fi

    FILE_TO_INSTALL+=("${BASENAME_FILE}")
  done < <(find "${CURRENT_DIR}/installations/"*.sh -not -name "__*" -type f -print0 | LC_ALL=C sort --zero-terminated)

  for install_file in "${FILE_TO_INSTALL[@]}"; do
    do_action "${install_file}" "${@}"
  done
}

source_bashrc() {
  if [[ -e "${HOME}/.bashrc" ]]; then
    print_title "Sourcing ~/.bashrc"
    set +u
    set +e
    PS1="$" source "${HOME}/.bashrc"
    set -e
    set -u
  fi
}

main() {
  local FILE_LIMIT=""
  local FILE_RESTART=0
  local DOTFILES_RC=0
  local RUN_SYMLINKS=0
  local RUN_CLEAN=0
  local RUN_INSTALL=0
  local RUN_PASSWORDS=0

  OPTIND=0
  while getopts ":l:r:acdhips" option; do
    case "${option}" in
    a)
      RUN_SYMLINKS=1
      RUN_CLEAN=1
      RUN_INSTALL=1
      RUN_PASSWORDS=1
      ;;
    c)
      RUN_CLEAN=1
      ;;
    d)
      DOTFILES_RC=1
      ;;
    h)
      usage
      return 1
      ;;
    i)
      RUN_INSTALL=1
      ;;
    p)
      RUN_PASSWORDS=1
      ;;
    s)
      RUN_SYMLINKS=1
      ;;
    l)
      FILE_LIMIT="$(printf -- "%s" "${OPTARG}" | tr "[:lower:]" "[:upper:]")"
      printf -- "Limiting to %s\n" "${FILE_LIMIT}"
      ;;
    r)
      FILE_LIMIT="$(printf -- "%s" "${OPTARG}" | tr "[:lower:]" "[:upper:]")"
      FILE_RESTART=1
      printf -- "Restarting at %s\n" "${FILE_LIMIT}"
      ;;
    :)
      printf -- "option -%s requires a value\n" "${OPTARG}" >&2
      exit 1
      ;;
    \?)
      printf -- "option -%s is invalid\n" "${OPTARG}" >&2
      usage
      exit 2
      ;;
    esac
  done

  shift $((OPTIND - 1))

  if [[ ${RUN_SYMLINKS} -eq 1 ]]; then
    print_title "symlinks"
    create_symlinks
  fi

  mkdir -p "${HOME}/opt/bin"
  source_bashrc

  if [[ ${DOTFILES_RC} -eq 1 ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
      do_mandatory_actions "install"
    fi

    source_bashrc
    create_dotfilesrc
    source_bashrc
  fi

  local ACTIONS=()

  if [[ ${RUN_CLEAN} -eq 1 ]]; then
    ACTIONS+=("clean")
  fi

  if [[ ${RUN_INSTALL} -eq 1 ]]; then
    ACTIONS+=("install")
  fi

  if [[ ${#ACTIONS[@]} -ne 0 ]]; then
    browse_actions "${ACTIONS[@]}"
    packages_clean
  fi

  source_bashrc

  if [[ ${RUN_PASSWORDS} -eq 1 ]]; then
    browse_actions "credentials"
  fi
}

main "${@}"
