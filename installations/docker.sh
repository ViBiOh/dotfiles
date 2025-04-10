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
  if command -v colima >/dev/null 2>&1; then
    colima delete --force
  fi

  sudo rm -rf "${HOME}/.docker" "${HOME}/.lima" "${HOME}/.colima"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/Caches/colima"
    rm -rf "${HOME}/Library/Caches/lima"
  fi
}

install() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "colima"
    colima completion bash >"${HOME}/opt/completions/colima-completion.sh"

    # safe guard on Apple Silicon to avoid silent error
    if ! [[ -d "/usr/local/bin" ]]; then
      sudo mkdir -p "/usr/local/bin"
    fi

    colima nerdctl install --path "${HOME}/opt/bin/docker" --force

    source "${SCRIPT_DIR}/../sources/docker.sh"

    docker_start
    docker completion bash | sed 's|nerdctl|docker|g' >"${HOME}/opt/completions/docker-completion.sh"
    docker_stop
  fi
}
