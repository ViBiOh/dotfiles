#!/usr/bin/env bash

add_to_path() {
  # Remove previous occurence of the path
  PATH=${PATH/${1}/}

  # Fix case when path was at the start
  PATH=${PATH#:}

  # Fix case when path was in the middle
  PATH=${PATH/::/:}

  # Fix case when path was at the end
  PATH=${PATH%:}

  # Add entry to the beginning of the PATH
  export PATH="${1}:${PATH}"
}

if [[ -d "${HOME}/opt/bin" ]]; then
  add_to_path "${HOME}/opt/bin"
fi
