#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  if [[ -n ${GOPATH:-} ]]; then
    sudo rm -rf "${GOPATH}"
    mkdir -p "${GOPATH}"
  fi

  rm -rf "${HOME}/.dlv"
  rm -rf "${HOME}/pprof"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/Caches/go-build"
    rm -rf "${HOME}/Library/Caches/golangci-lint"
    rm -rf "${HOME}/Library/Caches/gopls"
  fi
}

install() {
  if package_exists "go"; then
    packages_install "go"
  elif [[ ${OSTYPE} =~ ^linux ]]; then
    local GO_VERSION
    GO_VERSION=$(curl --disable --silent --show-error --location --max-time 30 'https://go.dev/VERSION?m=text' | head -1)

    local ARCH
    ARCH=$(dpkg --print-architecture)

    curl --disable --silent --show-error --location --max-time 300 --output "go.tar.gz" "https://go.dev/dl/${GO_VERSION}.linux-${ARCH}.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -xzf "go.tar.gz" -C /usr/local
    rm "go.tar.gz"
  fi

  if package_exists "golangci-lint"; then
    packages_install "golangci-lint"
  fi

  if package_exists "graphviz"; then
    packages_install "graphviz"
  fi

  if package_exists "go-size-analyzer"; then
    packages_install "go-size-analyzer"
  fi

  source "${DOTFILES_DIR}/sources/_golang.sh"
  mkdir -p "${GOPATH}"

  if command -v go >/dev/null 2>&1; then
    go telemetry off

    go install "github.com/derailed/popeye@latest"
    go install "github.com/go-delve/delve/cmd/dlv@latest"
    go install "github.com/tsenart/vegeta@latest"
    go install "golang.org/x/perf/cmd/benchstat@latest"
    go install "golang.org/x/tools/cmd/goimports@latest"
    go install "mvdan.cc/gofumpt@latest"
  fi

  if command -v golangci-lint >/dev/null 2>&1; then
    golangci-lint completion bash >"${HOME}/opt/completions/golangci-lint.bash"
  fi
}
