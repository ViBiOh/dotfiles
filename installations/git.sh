#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

symlink() {
  symlink_home ".gitconfig"
  symlink_home ".gitconfig_work"
  symlink_home ".gitignore_global"

  # https://git-scm.com/docs/git#Documentation/git.txt---list-cmdsltgroupgtltgroupgt82308203
  symlink_home "opt/bin/git-coco"
}

clean() {
  SYMLINK_ONLY_CLEAN=true symlink
}

install() {
  symlink

  packages_install "git"

  if package_exists "git-delta"; then
    packages_install "git-delta"
  fi

  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  curl --disable --silent --show-error --location --max-time 30 --output "${HOME}/opt/completions/git" "https://raw.githubusercontent.com/git/git/v$(git --version | awk '{printf("%s", $3)}')/contrib/completion/git-completion.bash"

  (
    cd "${DOTFILES_DIR}/"
    curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/ViBiOh/scripts/main/bootstrap.sh" | bash -s -- "-c" "git" "git_hooks"
  )
}
