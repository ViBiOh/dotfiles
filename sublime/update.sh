#!/usr/bin/env bash

set -e
set -u

rm -rf /usr/local/bin/subl
ln -f -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl

PKG="${HOME}/Library/Application Support/Sublime Text 3/Packages"
GOCODE_PKG="${PKG}/gocode"
PKG_USER="${PKG}/User"

mkdir -p "${PKG_USER}"

rm -rf "${GOCODE_PKG}" "${PKG_USER}/*"
cp -r gocode "${GOCODE_PKG}"
cp snippets/* "${PKG_USER}/"
cp settings/* "${PKG_USER}/"

if command -v go > /dev/null 2>&1; then
  echo
  echo Updating golang packages

  go get -u github.com/mdempsky/gocode
  go get -u github.com/sourcegraph/go-langserver
  go get -u golang.org/x/tools/cmd/gotype
fi

if command -v npm > /dev/null 2>&1; then
  npm install -g prettier javascript-typescript-langserver
fi

echo Success!
