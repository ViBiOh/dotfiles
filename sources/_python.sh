#!/usr/bin/env bash

if [[ -d "${HOME}/opt/python" ]]; then
  export VIRTUAL_ENV="${HOME}/opt/python/venv"
  add_to_path "${HOME}/opt/python/venv/bin"
fi

export UV_TOOL_DIR="${HOME}/opt/python/tools"
export UV_TOOL_BIN_DIR="${HOME}/opt/python/bin"
export UV_PYTHON_INSTALL_DIR="${HOME}/opt/python/uv"
add_to_path "${UV_TOOL_BIN_DIR}"
