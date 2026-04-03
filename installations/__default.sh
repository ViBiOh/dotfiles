#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".bashrc"
  symlink_home ".bash_profile"
  symlink_home ".bash_logout"
  symlink_home ".bash_sessions_disable"
  symlink_home ".curlrc"
  symlink_home ".editorconfig"
  symlink_home ".ignore"
  symlink_home ".inputrc"
}

clean() {
  sudo rm -rf "${HOME}/.config/htop" "${HOME}/opt"
  rm -rf "${HOME}/.cache"

  # Clean broken symlinks in home directory
  find "${HOME}" -maxdepth 1 -type l ! -exec test -e {} \; -exec rm {} \;

  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  local PACKAGES=("bash" "make" "grep" "htop" "openssl" "curl" "ncdu" "jq" "pv")

  mkdir -p "${HOME}/opt/bin"
  mkdir -p "${HOME}/opt/completions"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    PACKAGES+=("bash-completion@2")
    PACKAGES+=("pstree")

    if ! command -v brew >/dev/null 2>&1; then
      /bin/bash -c "$(curl --disable --silent --show-error --location "https://raw.githubusercontent.com/Homebrew/install/master/install.sh")"
      source "${DOTFILES_DIR}/sources/__homebrew.sh"
    fi

    packages_update
    packages_install "${PACKAGES[@]}" "awk"

    if [[ $(grep --count "${BREW_PREFIX}" "/etc/shells") -eq 0 ]]; then
      printf -- "+-------------------------+\n"
      printf -- "| changing shell for user |\n"
      printf -- "+-------------------------+\n"

      printf -- "%s/bin/bash\n" "${BREW_PREFIX}" | sudo tee -a "/etc/shells" >/dev/null
      chsh -s "${BREW_PREFIX}/bin/bash" -u "$(whoami)"
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    PACKAGES+=("bash-completion")

    packages_update
    packages_install "apt-transport-https"
    packages_install "${PACKAGES[@]}" "dnsutils" "jdupes"
  fi
}
