#!/usr/bin/env bash

set -e
set -u

echo "-------"
echo "- git -"
echo "-------"

curl -o "${HOME}/code/bin/diff-so-fancy" https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
chmod +x "${HOME}/code/bin/diff-so-fancy"
