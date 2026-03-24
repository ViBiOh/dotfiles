#!/usr/bin/env bash

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

if [[ -f "${HOME}/opt/google-cloud-sdk/path.bash.inc" ]]; then
  source "${HOME}/opt/google-cloud-sdk/path.bash.inc"
fi

if ! command -v gcloud >/dev/null 2>&1; then
  return
fi

if [[ -f "${HOME}/opt/google-cloud-sdk/completion.bash.inc" ]]; then
  source "${HOME}/opt/google-cloud-sdk/completion.bash.inc"
fi

source "$(script_dir)/../scripts/meta" && meta_init "gcloud"
