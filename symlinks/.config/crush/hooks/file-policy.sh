#!/usr/bin/env bash

set -o nounset -o pipefail

TARGET="${CRUSH_TOOL_INPUT_FILE_PATH:-}"
NAME="${TARGET##*/}"

if [[ ${NAME} == .env || ${NAME} == .env.* ]]; then
  printf -- "Blocked: %s\n" "${TARGET}" >&2
  exit 2
fi
