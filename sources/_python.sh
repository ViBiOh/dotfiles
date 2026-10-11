#!/usr/bin/env bash

export UV_TOOL_DIR="${HOME}/opt/python/tools"
export UV_TOOL_BIN_DIR="${HOME}/opt/python/bin"
add_to_path "${UV_TOOL_BIN_DIR}"

if [[ -d "${HOME}/opt/python" ]]; then
  export VIRTUAL_ENV="${HOME}/opt/python/venv"
  add_to_path "${HOME}/opt/python/venv/bin"
fi
