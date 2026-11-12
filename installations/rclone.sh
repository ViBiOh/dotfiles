#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.config/rclone/"
}

install() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    packages_install "rclone"
  else
    # renovate: datasource=github-releases depName=rclone/rclone
    local RCLONE_VERSION="v1.76.0"
    archive_to_binary "https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-$(normalized_os)-$(normalized_arch "amd64" "arm" "arm64").zip" "rclone-${RCLONE_VERSION}-$(normalized_os)-$(normalized_arch "amd64" "arm" "arm64")/rclone"
  fi
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/rclone-config" ".config/rclone/rclone.conf"
}
