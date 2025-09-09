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
  rm -rf "${HOME}/.config/gcloud"
}

install() {
  # renovate: datasource=docker depName=gcr.io/google.com/cloudsdktool/google-cloud-cli
  local GCLOUD_VERSION="538.0.0"

  local GCLOUD_ARCHIVE
  GCLOUD_ARCHIVE="google-cloud-sdk-${GCLOUD_VERSION}-$(normalized_os)-$(normalized_arch "" "arm" "arm").tar.gz"

  curl --disable --silent --show-error --location --max-time 300 --remote-name "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${GCLOUD_ARCHIVE}"
  rm -rf "${HOME}/opt/google-cloud-sdk"
  tar -C "${HOME}/opt" -xzf "${GCLOUD_ARCHIVE}"
  rm -rf "${GCLOUD_ARCHIVE}"

  source "$(script_dir)/../sources/gcloud.sh"

  if command -v gcloud >/dev/null 2>&1; then
    gcloud components update --quiet
    gcloud components install --quiet "gke-gcloud-auth-plugin"
  fi
}
