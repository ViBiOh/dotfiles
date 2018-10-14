#!/usr/bin/env bash

set -e
set -u

echo "---------"
echo "- Clean -"
echo "---------"

ls "${GOPATH}/pkg/" | xargs rm -rf
ls "${GOPATH}/bin/" | xargs rm -rf
ls "${GOPATH}/src" | grep -v 'github.com' | xargs rm -rf
ls "${GOPATH}/src/github.com" | grep -v 'ViBiOh' | xargs rm -rf

mkdir -p "${GOPATH}/pkg/" "${GOPATH}/bin/" "${GOPATH}/src/"
