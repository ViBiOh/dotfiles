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

install_plugin() {
  if [[ ${#} -ne 2 ]]; then
    var_red "Usage: install_plugin PACKAGES_FOLDER PLUGIN_NAME"
    return 1
  fi

  local PACKAGES_FOLDER="${1}"
  shift

  local PLUGIN_NAME="${1}"
  shift

  rm -rf "${PACKAGES_FOLDER:?}/${PLUGIN_NAME}"
  ln -s "${SCRIPT_DIR}/plugins/${PLUGIN_NAME}" "${PACKAGES_FOLDER}/${PLUGIN_NAME}"
}

symlink_settings() {
  if [[ ${#} -ne 2 ]]; then
    var_red "Usage: symlink_settings PACKAGE_FOLDER SETTING_TYPE"
    return 1
  fi

  local PACKAGE_FOLDER="${1}/User"
  shift
  local SETTING_TYPE="${1}"
  shift

  rm -rf "${PACKAGE_FOLDER:?}"/*
  mkdir -p "${PACKAGE_FOLDER}"

  if [[ -d "${SCRIPT_DIR}/${SETTING_TYPE}/settings/" ]]; then
    ln -s "${SCRIPT_DIR}/${SETTING_TYPE}/settings/"* "${PACKAGE_FOLDER}/"
  fi

  if [[ -d "${SCRIPT_DIR}/${SETTING_TYPE}/snippets/" ]]; then
    ln -s "${SCRIPT_DIR}/${SETTING_TYPE}/snippets/"* "${PACKAGE_FOLDER}/"
  fi
}

install_shfmt() {
  # renovate: datasource=github-releases depName=mvdan/sh
  local SHFMT_VERSION="v3.12.0"

  curl_to_binary "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_$(normalized_os)_$(normalized_arch "amd64" "arm" "arm64")" "shfmt"
}

main() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  local TEXT_PKG="${HOME}/.config/sublime-text/Packages"
  local MERGE_PKG="${HOME}/.config/sublime-merge/Packages"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    local TEXT_PKG="${HOME}/Library/Application Support/Sublime Text/Packages"
    local MERGE_PKG="${HOME}/Library/Application Support/Sublime Merge/Packages"
  fi

  source "${SCRIPT_DIR}/../sources/_binary.sh"

  symlink_settings "${TEXT_PKG}" "text"
  symlink_settings "${MERGE_PKG}" "merge"

  install_plugin "${TEXT_PKG}" "Formatter"
  install_plugin "${TEXT_PKG}" "SublimeGit"
  install_plugin "${TEXT_PKG}" "SublimeGo"
  install_plugin "${TEXT_PKG}" "SublimeLayout"
  install_plugin "${TEXT_PKG}" "SublimeMakefile"

  if command -v go >/dev/null 2>&1; then
    go install "golang.org/x/tools/gopls@latest"
  fi

  if command -v npm >/dev/null 2>&1; then
    npm install --ignore-scripts --global "prettier" "eslint" "typescript-language-server" "typescript" "yaml-language-server"
  fi

  if command -v pip >/dev/null 2>&1; then
    pip install "python-lsp-server" "black" "isort" "pycodestyle"

    cat >"${HOME}/.config/pycodestyle" <<PYCODESTYLEEND
[pycodestyle]
max-line-length = 160
PYCODESTYLEEND
  fi

  install_shfmt
}

main "${@}"
