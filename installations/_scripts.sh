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
  rm -rf "$(script_dir)/../scripts"
}

install() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(script_dir)"

  (
    cd "${SCRIPT_DIR}/../"
    curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/ViBiOh/scripts/main/bootstrap.sh" | bash -s -- "-c" \
      "gcloud" \
      "git" \
      "git_coco.sh" \
      "github" \
      "http" \
      "kubernetes" \
      "pass" \
      "rotate.sh" \
      "scw" \
      "ssh" \
      "tmux" \
      "var" \
      "version"

    # https://git-scm.com/docs/git#Documentation/git.txt---list-cmdsltgroupgtltgroupgt82308203
    source "${SCRIPT_DIR}/../scripts/git"
    ln -s -f "${SCRIPT_DIR}/../scripts/git_coco.sh" "${HOME}/opt/bin/git-coco"

    if command -v git >/dev/null 2>&1 && git_is_inside; then
      curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/ViBiOh/scripts/main/bootstrap.sh" | bash -s -- "git_hooks"
    fi
  )

  source "${SCRIPT_DIR}/../scripts/meta" && meta_check "var"
}
