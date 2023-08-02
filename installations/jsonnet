#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  # renovate: datasource=github-releases depName=google/go-jsonnet
  local JSONNET_VERSION="v0.20.0"

  archive_to_binary "https://github.com/google/go-jsonnet/releases/download/${JSONNET_VERSION}/go-jsonnet_${JSONNET_VERSION#v}_$(normalized_os "Darwin")_$(normalized_arch "" "" "arm64").tar.gz" "jsonnet"

  # renovate: datasource=github-releases depName=grafana/mimir
  local MIMIR_VERSION="2.7.2"

  curl_to_binary "https://github.com/grafana/mimir/releases/download/mimir-${MIMIR_VERSION}/mimirtool-$(normalized_os)-$(normalized_arch "amd64" "" "arm64")" "mimirtool"
}
