#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Golang -"
echo "----------"

if [ `uname -s` == 'Darwin' ]; then
  brew install golang
fi

if command -v go > /dev/null 2>&1; then
  source "${HOME}/code/src/github.com/ViBiOh/dotfiles/sources/golang"

  if [ `uname -m` == 'x86_64' ]; then
    go get -u github.com/derekparker/delve/cmd/dlv
  fi

  go get -u github.com/golang/dep/cmd/dep
  go get -u github.com/google/pprof
  go get -u github.com/kisielk/errcheck
  go get -u golang.org/x/lint/golint
  go get -u golang.org/x/tools/cmd/goimports
fi
