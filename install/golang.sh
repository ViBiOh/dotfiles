#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clean() {
  if [[ -n "${GOPATH-}" ]]; then
    rm -rf "${GOPATH}/pkg/" "${GOPATH}/bin/" "${HOME}/.dlv"
    mkdir -p "${GOPATH}/pkg/" "${GOPATH}/bin/" "${GOPATH}/src/"

    pushd "${GOPATH}/src"
    for src in $(ls | grep -v 'github.com'); do
      rm -rf "${src}"
    done

    pushd "${GOPATH}/src/github.com"
    for src in $(ls | grep -v 'ViBiOh'); do
      rm -rf "${src}"
    done

    popd
    popd
  fi
}

main() {
  clean

  local GO_VERSION=1.11.5
  local OS=$(uname -s)
  local ARCH=$(uname -m)

  if [[ "${ARCH}" == "x86_64" ]]; then
    ARCH="amd64"
  elif [[ "${ARCH}" =~ ^armv.l$ ]]; then
    ARCH="armv6l"
  fi

  local GO_ARCHIVE="go${GO_VERSION}.${OS,,}-${ARCH,,}.tar.gz"

  curl -O "https://dl.google.com/go/${GO_ARCHIVE}"
  rm -rf "${HOME}/opt/go"
  tar -C "${HOME}/opt" -xzf "${GO_ARCHIVE}"
  rm -rf "${GO_ARCHIVE}"

  source "${SCRIPT_DIR}/../sources/golang"

  if command -v go > /dev/null 2>&1; then
    if [[ "${ARCH}" == "amd64" ]]; then
      go get -u github.com/derekparker/delve/cmd/dlv
    fi

    go get -u github.com/cjbassi/gotop
    go get -u github.com/golang/dep/cmd/dep
    go get -u github.com/google/pprof
    go get -u github.com/kisielk/errcheck
    go get -u golang.org/x/lint/golint
    go get -u golang.org/x/tools/cmd/goimports
  fi
}

main
