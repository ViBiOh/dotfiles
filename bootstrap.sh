#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  local INSTALL_PATH="${HOME}/code"
  local GITHUB_USER="ViBiOh"
  local REPOSITORY_NAME="dotfiles"
  local DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
  local ARCHIVE_FILENAME="${INSTALL_PATH}/${REPOSITORY_NAME}.zip"

  mkdir -p "${INSTALL_PATH}"

  curl --disable --silent --show-error --location --max-time 60 --output "${ARCHIVE_FILENAME}" "https://github.com/${GITHUB_USER}/${REPOSITORY_NAME}/archive/${DOTFILES_BRANCH}.zip"
  unzip "${ARCHIVE_FILENAME}" -d "${INSTALL_PATH}"
  rm -f "${ARCHIVE_FILENAME}"

  rm -rf "${INSTALL_PATH:?}/${REPOSITORY_NAME}"
  mv "${INSTALL_PATH}/${REPOSITORY_NAME}-${DOTFILES_BRANCH}" "${INSTALL_PATH}/${REPOSITORY_NAME}"

  (
    cd "${INSTALL_PATH}/${REPOSITORY_NAME}"
    "./init.sh" -d -a

    if command -v git >/dev/null 2>&1; then
      git init
      git remote add origin "https://github.com/${GITHUB_USER}/${REPOSITORY_NAME}.git"
      git fetch origin
      git checkout --force "${DOTFILES_BRANCH}"
    fi
  )
}

main
