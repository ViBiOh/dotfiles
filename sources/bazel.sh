#!/usr/bin/env bash

if ! command -v bzl >/dev/null 2>&1; then
  return
fi

bzl_run() {
  local BZL_TARGET
  BZL_TARGET="$(bzl query ... 2>/dev/null | fzf --select-1 --query="${1:-}")"

  if [[ -n ${BZL_TARGET:-} ]]; then
    var_print_and_run bzl run --ui_event_filters=-INFO,-DEBUG,-STDOUT,-STDERR --show_progress_rate_limit=10 "${BZL_TARGET}"
  fi
}

gazelle() {
  local CURRENT_DIR
  CURRENT_DIR="$(readlink -f "$(pwd)")"

  local GIT_ROOT_PATH
  GIT_ROOT_PATH="$(git rev-parse --show-toplevel)"

  local GAZELLE_TARGET="${CURRENT_DIR#"${GIT_ROOT_PATH}"}"

  var_print_and_run bzl run --ui_event_filters=-INFO,-DEBUG,-STDOUT,-STDERR //:gazelle -- fix "${GAZELLE_TARGET#/}"
}

bazel_hard_clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    rm -rf "${HOME}/Library/Caches/bazel"
    rm -rf "${HOME}/Library/Caches/bazelisk"

    sudo rm -rf "/var/tmp/_bazel_$(whoami)"
    sudo mkdir -p "/var/tmp/_bazel_$(whoami)"
    sudo chown "$(whoami)" "/var/tmp/_bazel_$(whoami)"
  fi
}
