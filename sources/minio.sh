#!/usr/bin/env bash

if ! command -v mc >/dev/null 2>&1; then
  return
fi

complete -C mc mc
