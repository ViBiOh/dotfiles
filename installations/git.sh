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

install() {
  packages_install "git" "git-lfs"

  if package_exists "git-delta"; then
    packages_install "git-delta"
  fi

  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  curl_to_binary "https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo" "git-filter-repo"

  curl --disable --silent --show-error --location --max-time 30 --output "$(script_dir)/../sources/git-prompt" "https://raw.githubusercontent.com/git/git/v$(git --version | awk '{printf("%s", $3)}')/contrib/completion/git-prompt.sh"
}
