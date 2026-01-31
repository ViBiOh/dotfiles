#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  # renovate: datasource=github-releases depName=mikefarah/yq
  local YQ_VERSION="v4.52.1"

  curl_to_binary "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_$(normalized_os)_$(normalized_arch "amd64" "arm" "arm64")" "yq"

  yq completion bash >"${HOME}/opt/completions/yq-completion.sh"
}
