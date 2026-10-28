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

  fileName="${DOTFILES_SOURCES_DIR}/../tools/sublime/projects/${projectName}.sublime-project"
  mkdir -p "$(dirname "${fileName}")"

  jq --compact-output --null-input --arg path "${currentDir}" '{folders: [{path: $path}]}' >"${fileName}"
  subl --project "${fileName}"
}

sublime_local_githubpullrequest() {
  local TEXT_PKG="${HOME}/.config/sublime-text/Packages"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    local TEXT_PKG="${HOME}/Library/Application Support/Sublime Text/Packages"
  fi

  rm -rf "${TEXT_PKG}/GitHubPullRequest"
  ln -s "${HOME}/code/sublime-GitHubPullRequest" "${TEXT_PKG}/GitHubPullRequest"
}
