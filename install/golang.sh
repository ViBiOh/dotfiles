#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Golang -"
echo "----------"

GO_VERSION=1.11.3
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "${ARCH}" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "${ARCH}" =~ ^armv.l$ ]]; then
  ARCH="armv6l"
fi

GO_ARCHIVE="go${GO_VERSION}.${OS,,}-${ARCH,,}.tar.gz"

curl -O "https://dl.google.com/go/${GO_ARCHIVE}"
rm -rf "${HOME}/opt/go"
tar -C "${HOME}/opt" -xzf "${GO_ARCHIVE}"
rm -rf "${GO_ARCHIVE}"

source "${HOME}/code/src/github.com/ViBiOh/dotfiles/sources/golang"

if command -v go > /dev/null 2>&1; then
  rm -rf "${GOPATH}/pkg/" "${GOPATH}/bin/" "${HOME}/.dlv"
  mkdir -p "${GOPATH}/pkg/" "${GOPATH}/bin/" "${GOPATH}/src/"

  ls "${GOPATH}/src" | grep -v 'github.com' | xargs rm -rf
  ls "${GOPATH}/src/github.com" | grep -v 'ViBiOh' | xargs rm -rf

  if [[ "${ARCH}" == "amd64" ]]; then
    go get -u github.com/derekparker/delve/cmd/dlv
  fi

  go get -u github.com/golang/dep/cmd/dep
  go get -u github.com/google/pprof
  go get -u github.com/kisielk/errcheck
  go get -u golang.org/x/lint/golint
  go get -u golang.org/x/tools/cmd/goimports
fi
