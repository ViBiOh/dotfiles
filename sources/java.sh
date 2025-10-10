#!/usr/bin/env bash

if [[ -d "${BREW_PREFIX}/opt/openjdk/bin" ]]; then
  export JAVA_HOME="${BREW_PREFIX}/opt/openjdk"
  add_to_path "${JAVA_HOME}/bin"
fi
