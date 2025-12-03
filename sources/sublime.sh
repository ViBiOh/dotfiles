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

SUBLIME_SCRIPT_DIR="$(script_dir)"

sublime_add_project() {
  local currentDir
  currentDir="$(readlink -f "$(pwd)")"

  if git_is_inside; then
    if [[ ${currentDir} != $(git_root) ]]; then
      if ! var_confirm "Current dir is not the root of the Git repository. Continue"; then
        return
      fi
    fi
  else
    var_error "Not inside a Git repository"
    return
  fi

  local projectName
  projectName="$(basename "${currentDir}")"

  if [[ -n ${NAME_PREFIX} ]]; then
    projectName="${NAME_PREFIX}_${projectName}"
  fi

  fileName="${SUBLIME_SCRIPT_DIR}/../sublime/projects/${projectName}.sublime-project"
  jq --compact-output --null-input --arg path "${currentDir}" '{folders: [{path: $path}]}' >"${fileName}"
  subl --project "${fileName}"
}
