#!/usr/bin/env bash

set +e

rm -rf /usr/local/bin/subl
ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl

PKG_USER="/Users/`whoami`/Library/Application Support/Sublime Text 3/Packages/User"
mkdir -p "${PKG_USER}"

rm -rf "${PKG_USER}/*"
cp snippets/* "${PKG_USER}/"
cp settings/* "${PKG_USER}/"


if command -v go > /dev/null 2>&1; then
  echo
  echo Updating golang packages

  go get -v -u golang.org/x/tools/cmd/guru
  go get -v -u github.com/nsf/gocode
fi

echo Success!
