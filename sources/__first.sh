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

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

export DOTFILES_SOURCES_DIR="$(script_dir)"
