#!/usr/bin/env bash

set -o nounset -o pipefail

CMD="${CRUSH_TOOL_INPUT_COMMAND:-}"

# Strip leading whitespace (spaces, tabs, newlines) then collapse internal runs
# of spaces and tabs to a single space. This prevents spacing tricks such as a
# leading space or a tab between a command and its subcommand from bypassing the
# pattern matching below.
NORMALIZED="${CMD#"${CMD%%[![:space:]]*}"}"
NORMALIZED="$(printf -- '%s' "${NORMALIZED}" | tr -s ' \t' ' ')"

DENY_PATTERNS=(
  # Brew
  '^brew'

  # Bazel
  '^bzl (build|run|test)'
  '^BZL_'

  # GitHub CLI
  '^gh '

  # Git mutations
  '^git (add|am|apply|branch|checkout|cherry-pick|clone|commit|config|filter-branch|gc|init|merge|mv|prune|pull|push|rebase|remote|reset|restore|revert|rm|stash|submodule|switch|tag|update-ref|worktree)'

  # Docker mutations (and the compatible CLIs / VM manager)
  '^docker (build|commit|compose|container|cp|create|exec|export|image|import|kill|load|login|network|pause|pull|push|restart|rm|rmi|run|save|start|stop|system|tag|unpause|update|volume)'
  '^(docker-compose|podman|nerdctl|colima)'

  # Package installs
  '^(go install|npm install|pip install)'

  # Terraform (running or installing it)
  '^terraform'
  '^tfenv'
)

for pattern in "${DENY_PATTERNS[@]}"; do
  if [[ ${NORMALIZED} =~ ${pattern} ]]; then
    printf -- "Blocked: %s\n" "${CMD}" >&2
    exit 2
  fi
done

# Only a single, simple command may be auto-approved. Anything that could chain
# or smuggle a second command (operators, command substitution, redirection,
# newlines) is not eligible for auto-approval and falls through to Crush's normal
# permission prompt, so a command like `cat x && rm -rf ~` cannot ride in on the
# allow list.
case ${NORMALIZED} in
*[\;\|\&\`\<\>\(\)]* | *'$('* | *'${'* | *$'\n'*)
  exit 0
  ;;
esac

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
  if [[ ${NORMALIZED} =~ ${pattern} ]]; then
    printf -- '{"decision":"allow"}\n'
    exit 0
  fi
done
