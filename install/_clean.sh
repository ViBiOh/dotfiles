#!/usr/bin/env bash

set -e
set -u

echo "---------"
echo "- Clean -"
echo "---------"

source "${HOME}/code/src/github.com/ViBiOh/dotfiles/sources/golang"

rm -rf "${GOPATH}/pkg/" "${GOPATH}/bin/"
mkdir -p "${GOPATH}/pkg/" "${GOPATH}/bin/"
ls "${GOPATH}/src" | grep -v 'github.com' | xargs rm -rf
ls "${GOPATH}/src/github.com" | grep -v 'ViBiOh' | xargs rm -rf

mkdir -p "${GOPATH}/pkg/" "${GOPATH}/bin/" "${GOPATH}/src/"
