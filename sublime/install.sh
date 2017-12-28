#!/usr/bin/env bash

ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl
PKG_USER="/Users/`whoami`/Library/Application Support/Sublime Text 3/Packages/User/"
mkdir -p "${PKG_USER}"
cp snippets/* "${PKG_USER}"
cp settings/* "${PKG_USER}"
