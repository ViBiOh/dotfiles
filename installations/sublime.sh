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
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo rm -rf "${HOME}/Library/Caches/Sublime Text"
    sudo rm -rf "${HOME}/Library/Caches/Sublime Merge"
  fi
}

install() {
  local ARCH
  ARCH="$(normalized_arch)"

  if command -v pacman >/dev/null 2>&1 && [[ $(grep -c "sublime-text" "/etc/pacman.conf") -eq 0 ]]; then
    curl --disable --silent --show-error --location --max-time 30 "https://download.sublimetext.com/sublimehq-pub.gpg" | sudo pacman-key --add -
    sudo pacman-key --lsign-key "8A8F901A"
    printf -- "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/%s" "${ARCH}" | sudo tee -a "/etc/pacman.conf"
  fi

  if package_exists "sublime-merge"; then
    packages_install_desktop "sublime-merge"
  fi

  local SUBLIME_TEXT_VERSION
  SUBLIME_TEXT_VERSION="$(curl --disable --silent --show-error --location --max-time 30 "https://www.sublimetext.com/updates/4/dev_update_check" | jq ".latest_version")"

  local SUBLIME_TEXT_STABLE_VERSION
  SUBLIME_TEXT_STABLE_VERSION="$(curl --disable --silent --show-error --location --max-time 30 "https://www.sublimetext.com/updates/4/stable_update_check" | jq ".latest_version")"

  if [[ ${SUBLIME_TEXT_VERSION} < ${SUBLIME_TEXT_STABLE_VERSION} ]]; then
    SUBLIME_TEXT_VERSION="${SUBLIME_TEXT_STABLE_VERSION}"
  fi

  local FILENAME_SUFFIX
  FILENAME_SUFFIX="$(normalized_arch "amd64" "arm" "arm64").tar.xz"

  local OUTPUT_FOLDER="${HOME}/opt/"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    OUTPUT_FOLDER="/Applications/"
    FILENAME_SUFFIX="mac.zip"
    rm -rf "${OUTPUT_FOLDER}/Sublime Text.app"
  fi

  local SUBLIME_TEXT_FILENAME="sublime_text_build_${SUBLIME_TEXT_VERSION}_${FILENAME_SUFFIX}"
  curl --disable --silent --show-error --location --max-time 300 --remote-name "https://download.sublimetext.com/${SUBLIME_TEXT_FILENAME}"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    unzip -d "${OUTPUT_FOLDER}" -o "${SUBLIME_TEXT_FILENAME}"
    ln -f -s "${OUTPUT_FOLDER}/Sublime Text.app/Contents/SharedSupport/bin/subl" "${HOME}/opt/bin/subl"
  else
    tar -xf "${SUBLIME_TEXT_FILENAME}" -C "${OUTPUT_FOLDER}"
    ln -f -s "${OUTPUT_FOLDER}/sublime_text/sublime_text" "${HOME}/opt/bin/subl"
  fi

  rm -rf "${SUBLIME_TEXT_FILENAME}"

  if command -v subl >/dev/null 2>&1; then
    "$(script_dir)/../sublime/init.sh"
  fi
}
