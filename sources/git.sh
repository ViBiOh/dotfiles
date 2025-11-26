#!/usr/bin/env bash

if ! command -v git >/dev/null 2>&1; then
  return
fi

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
  git update-index --index-version 4
  git config core.fsmonitor true
  git config fetch.writeCommitGraph true
  git commit-graph write --reachable
}

git_large_repos_status() {
  git fsmonitor--daemon status
}
