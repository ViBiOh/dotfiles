#!/usr/bin/env bash

[[ -z ${PS1-} ]] && return

set_locale() {
  local LOCALES=("en_US.UTF-8" "en_US.utf8" "C.UTF-8" "C")
  local ALL_LOCALES
  ALL_LOCALES="$(locale -a)"

  for locale in "${LOCALES[@]}"; do
    if [[ $(echo "${ALL_LOCALES}" | grep --count "${locale}") -eq 1 ]]; then
      export LC_ALL="${locale}"
      export LANG="${locale}"
      export LANGUAGE="${locale}"

      return
    fi
  done

  return 1
}

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

source_if_exists() {
  if [[ -e ${1} ]]; then
    source "${1}"
  fi
}

DOTFILES_SOURCES_DIR="$(script_dir)"
export DOTFILES_SOURCES_DIR

set_locale

if [[ -e "${DOTFILES_SOURCES_DIR}/../scripts/meta" ]]; then
  source "${DOTFILES_SOURCES_DIR}/../scripts/meta" && meta_init "var"
fi

for file in "${DOTFILES_SOURCES_DIR}/../sources/"*; do
  [[ -r ${file} ]] && [[ -f ${file} ]] && source "${file}"
done

source_if_exists "${DOTFILES_SOURCES_DIR}/../../work/bash_source.sh"
source_if_exists "${HOME}/.localrc"

unset -f set_locale
unset -f script_dir
unset -f source_if_exists
