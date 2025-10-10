#!/usr/bin/env bash

add_to_path() {
  # Remove previous occurence of the directory
  PATH=${PATH/${1}/}

  # Fix possible colon previously here
  PATH=${PATH/::/:}

  # Add entry to the beginning of the PATH
  export PATH="${1}:${PATH}"
}

if [[ -d "${HOME}/opt/bin" ]]; then
  add_to_path "/opt/homebrew/bin"
  add_to_path "${HOME}/opt/bin"
fi
