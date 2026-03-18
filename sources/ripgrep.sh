#!/usr/bin/env bash

if ! command -v rg >/dev/null 2>&1; then
  return
fi

export RIPGREP_CONFIG_PATH="${HOME}/.ripgreprc"
