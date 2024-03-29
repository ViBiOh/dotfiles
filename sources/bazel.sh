#!/usr/bin/env bash

bzl_run() {
  local BZL_TARGET
  BZL_TARGET="$(bzl query ... 2>/dev/null | fzf --select-1 --query="${1:-}")"

  if [[ -n ${BZL_TARGET} ]]; then
    var_print_and_run bzl run "${BZL_TARGET}"
  fi
}
