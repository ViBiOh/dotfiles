#!/usr/bin/env bash

export HOMEBREW_NO_ANALYTICS="1"
export HOMEBREW_NO_INSECURE_REDIRECT="1"
export HOMEBREW_CASK_OPTS="--require-sha"

if [[ -d /opt/homebrew/bin ]]; then
  add_to_path "/opt/homebrew/bin"
fi

if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  export BREW_PREFIX

  add_to_path "${BREW_PREFIX}/sbin"
  add_to_path "${BREW_PREFIX}/bin"
  add_to_path "${BREW_PREFIX}/opt/curl/bin"
  add_to_path "${BREW_PREFIX}/opt/make/libexec/gnubin"
  add_to_path "${BREW_PREFIX}/opt/grep/libexec/gnubin"
  add_to_path "${BREW_PREFIX}/opt/openssl/bin"
  add_to_path "${BREW_PREFIX}/opt/ruby/bin"
  add_to_path "${BREW_PREFIX}/opt/libpq/bin"

  brew_specific_version() {
    # cf. https://github.com/orgs/Homebrew/discussions/155

    brew tap-new "$(whoami)/${1}"
    brew extract --version "${2}" "${1}" "$(whoami)/${1}"
    brew install "${1}/${2}"
  }
fi
