#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

clean() {
  if [[ -n ${GOPATH-} ]]; then
    sudo rm -rf "${GOPATH}"
    mkdir -p "${GOPATH}"
  fi

  rm -rf "${HOME}/.dlv"
  rm -rf "${HOME}/pprof"
}

install() {
  packages_install "go" "graphviz"

  source "$(script_dir)/../sources/_golang.sh"
  mkdir -p "${GOPATH}"

  if command -v go >/dev/null 2>&1; then
    go install "github.com/derailed/popeye@latest"
    go install "github.com/go-delve/delve/cmd/dlv@latest"
    go install "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
    go install "github.com/tsenart/vegeta@latest"
    go install "go.uber.org/mock/mockgen@latest"
    go install "golang.org/x/tools/cmd/goimports@latest"
    go install "golang.org/x/tools/cmd/stringer@latest"
    go install "golang.org/x/tools/go/analysis/passes/fieldalignment/cmd/fieldalignment@master"
    go install "mvdan.cc/gofumpt@latest"

    golangci-lint completion bash >"${HOME}/opt/completions/golangci-lint-completion.sh"
  fi
}
