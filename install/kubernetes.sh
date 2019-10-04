#!/usr/bin/env bash

# set -o nounset -o pipefail -o errexit

install() {
  local OS="$(uname -s | tr "[:upper:]" "[:lower:]")"
  local ARCH="$(uname -m | tr "[:upper:]" "[:lower:]")"

  if [[ "${ARCH}" = "x86_64" ]]; then
    ARCH="amd64"
  elif [[ "${ARCH}" =~ ^armv.l$ ]]; then
    ARCH="arm"
  fi

  local KUBERNETES_VERSION="$(curl -q -sS https://storage.googleapis.com/kubernetes-release/release/stable.txt)"
  curl -q -sS -L -o "${HOME}/opt/bin/kubectl" "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/${OS}/${ARCH}/kubectl"
  chmod +x "${HOME}/opt/bin/kubectl"
}
