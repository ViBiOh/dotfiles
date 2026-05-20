#!/usr/bin/env bash

set -o nounset -o pipefail

CMD="${CRUSH_TOOL_INPUT_COMMAND:-}"

DENY_PATTERNS=(
  # Bazel
  '^bzl (build|run|test)'
  '^BZL_'

  # GitHub CLI
  '^gh '

  # Git mutations
  '^git (add|checkout|clone|commit|init|merge|pull|push|rebase|rm|switch|tag|worktree)'

  # Package installs
  '^(go install|npm install|pip install)'
)

for pattern in "${DENY_PATTERNS[@]}"; do
  if [[ ${CMD} =~ ${pattern} ]]; then
    printf -- "Blocked: %s\n" "${CMD}" >&2
    exit 2
  fi
done

ALLOW_PATTERNS=(
  '^cargo test'
  '^cat'
  '^cd'
  '^find'
  '^git diff'
  '^go (build|doc|generate|test|vet)'
  '^gofumpt'
  '^golangci-lint'
  '^grep'
  '^head'
  '^ls'
  '^mockgen'
  '^npm (run test|test)'
  '^prettier'
  '^pytest'
  '^tee'
  '^wc'
  '^xargs grep'
)

for pattern in "${ALLOW_PATTERNS[@]}"; do
  if [[ ${CMD} =~ ${pattern} ]]; then
    printf -- '{"decision":"allow"}\n'
    exit 0
  fi
done
