#!/usr/bin/env bash

if command -v brew >/dev/null 2>&1; then
  add_to_path "${BREW_PREFIX:-}/opt/python/libexec/bin"
fi

if [[ -d "${HOME}/opt/python" ]]; then
  export VIRTUAL_ENV="${HOME}/opt/python/venv"
  add_to_path "${HOME}/opt/python/venv/bin"
fi
