#!/usr/bin/env bash

if ! command -v subl >/dev/null 2>&1; then
  return
fi

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

  if [[ -n ${NAME_PREFIX:-} ]]; then
    projectName="${NAME_PREFIX}_${projectName}"
  fi

  fileName="${DOTFILES_SOURCES_DIR}/../sublime/projects/${projectName}.sublime-project"
  jq --compact-output --null-input --arg path "${currentDir}" '{folders: [{path: $path}]}' >"${fileName}"
  subl --project "${fileName}"
}
