#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

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

clean() {
  sudo rm -rf "${HOME}/.config/htop" "${HOME}/opt"
  rm -rf "${HOME}/.cache"

  # Clean broken symlinks in home directory
  find "${HOME}" -maxdepth 1 -type l ! -exec test -e {} \; -exec rm {} \;
}

install() {
  local PACKAGES=("bash" "make" "grep" "htop" "openssl" "curl" "ncdu" "jq" "pv")

  mkdir -p "${HOME}/opt/bin"
  mkdir -p "${HOME}/opt/completions"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    cat >"${HOME}/.bash_profile" <<END_OF_BASH_PROFILE
#!/usr/bin/env bash

export SSH_INIT_FROM_FILE="true"

if [[ -f "${HOME}/.bashrc" ]]; then
  source "${HOME}/.bashrc"
fi
END_OF_BASH_PROFILE

    PACKAGES+=("bash-completion@2")
    PACKAGES+=("pstree")

    if ! command -v brew >/dev/null 2>&1; then
      /bin/bash -c "$(curl --disable --silent --show-error --location "https://raw.githubusercontent.com/Homebrew/install/master/install.sh")"
      source "$(script_dir)/../sources/_homebrew.sh"
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
  elif command -v pacman >/dev/null 2>&1; then
    PACKAGES+=("bash-completion")

    packages_update
    packages_install "${PACKAGES[@]}" "inetutils" "tcpdump"
  fi
}
