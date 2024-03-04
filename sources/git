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

git_large_repos() {
  git config feature.manyFiles true
  git update-index --index-version 4
  git config core.fsmonitor true
  git config core.untrackedcache true
  git config core.commitgraph true
}
