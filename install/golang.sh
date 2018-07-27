#!/usr/bin/env bash

set -e
set -u

echo "----------"
echo "- Golang -"
echo "----------"

if [ `uname` == 'Darwin' ]; then
  brew reinstall golang graphviz
fi

if command -v go > /dev/null 2>&1; then
  rm -rf ${GOPATH}/bin/* ${GOPATH}/pkg/* ${GOPATH}/src/golang.org
  ls $GOPATH/src/github.com | grep -v ViBiOh | xargs rm -rf

  go get -u github.com/derekparker/delve/cmd/dlv
  go get -u github.com/golang/dep/cmd/dep
  go get -u github.com/golang/lint/golint
  go get -u github.com/google/pprof
  go get -u github.com/kisielk/errcheck
  go get -u golang.org/x/tools/cmd/goimports
fi
