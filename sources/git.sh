#!/usr/bin/env bash

if ! command -v git >/dev/null 2>&1; then
  return
fi

source "${DOTFILES_SOURCES_DIR}/../scripts/meta" && meta_init "git"

if command -v delta >/dev/null 2>&1; then
  export GIT_PAGER='delta --dark'
fi

...() {
  cd "$(git_root)" || return 1
}

# https://blog.gitbutler.com/git-tips-3-really-large-repositories/
# https://www.git-tower.com/blog/git-performance/
git_large_repos() {
  git config index.threads true
  git config feature.manyFiles true
  git config core.fsmonitor true
  git config fetch.writeCommitGraph true
  git commit-graph write --reachable
}

git_large_repos_status() {
  git fsmonitor--daemon status
}

git_repository() {
  if ! git_is_inside; then
    return
  fi

  local REMOTE_URL
  REMOTE_URL="$(git remote get-url --push "$(git remote show | head -1)")"

  if [[ ${REMOTE_URL} =~ ^.*@(.*)[:/](.*)/(.*)$ ]]; then
    jq --null-input --compact-output \
      --arg url "${BASH_REMATCH[1]}" \
      --arg owner "${BASH_REMATCH[2]}" \
      --arg name "${BASH_REMATCH[3]%.git}" \
      '{
          url: $url,
          owner: $owner,
          name: $name
        }'
  fi
}
