#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${DOTFILES_DIR}/scripts"
}

install() {
  (
    cd "${DOTFILES_DIR}/"
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
    source "${DOTFILES_DIR}/scripts/git"
    ln -s -f "${DOTFILES_DIR}/scripts/git_coco.sh" "${HOME}/opt/bin/git-coco"

    if command -v git >/dev/null 2>&1 && git_is_inside; then
      curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/ViBiOh/scripts/main/bootstrap.sh" | bash -s -- "git_hooks"
    fi
  )

  source "${DOTFILES_DIR}/scripts/meta" && meta_check "var"
}
