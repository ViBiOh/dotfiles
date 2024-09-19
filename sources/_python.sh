#!/usr/bin/env bash

if command -v brew >/dev/null 2>&1; then
  export PATH="${BREW_PREFIX:-}/opt/python/libexec/bin:${PATH}"
fi

if [[ -d "${HOME}/opt/python" ]]; then
  export PATH="${HOME}/opt/python/venv/bin:${PATH}"
fi
