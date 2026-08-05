#!/usr/bin/env bash

sublime_text_dev_version() {
  curl --disable --silent --show-error --location --max-time 30 "https://www.sublimetext.com/updates/4/dev_update_check" | jq ".latest_version"
}

sublime_text_stable_version() {
  curl --disable --silent --show-error --location --max-time 30 "https://www.sublimetext.com/updates/4/stable_update_check" | jq ".latest_version"
}

sublime_merge_dev_version() {
  curl --disable --silent --show-error --location --max-time 30 "https://www.sublimemerge.com/updates/dev_update_check" | jq ".latest_version"
}

sublime_merge_stable_version() {
  curl --disable --silent --show-error --location --max-time 30 "https://www.sublimemerge.com/updates/stable_update_check" | jq ".latest_version"
}

sublime_versions() {
  var_green "SublimeText"
  var_info "Stable version: $(sublime_text_stable_version)"
  var_warning "Dev version: $(sublime_text_dev_version)"

  var_green ""

  var_green "SublimeMerge"
  var_info "Stable version: $(sublime_merge_stable_version)"
  var_warning "Dev version: $(sublime_merge_dev_version)"
}

sublime_text_install() {
  if [[ ${#} -ne 1 ]]; then
    var_error "Usage sublime_text_install SUBLIME_TEXT_VERSION"
    return 1
  fi

  local SUBLIME_TEXT_VERSION="${1}"
  shift

  local FILENAME_SUFFIX
  FILENAME_SUFFIX="$(normalized_arch "amd64" "arm" "arm64").tar.xz"

  local OUTPUT_FOLDER="${HOME}/opt/"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    OUTPUT_FOLDER="${HOME}/Applications"
    FILENAME_SUFFIX="mac.zip"
    rm -rf "${OUTPUT_FOLDER}/Sublime Text.app"
  fi

  local SUBLIME_TEXT_FILENAME="sublime_text_build_${SUBLIME_TEXT_VERSION}_${FILENAME_SUFFIX}"
  curl --disable --silent --show-error --location --max-time 300 --remote-name "https://download.sublimetext.com/${SUBLIME_TEXT_FILENAME}"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    unzip -d "${OUTPUT_FOLDER}" -o "${SUBLIME_TEXT_FILENAME}"
    ln -f -s "${OUTPUT_FOLDER}/Sublime Text.app/Contents/SharedSupport/bin/subl" "${HOME}/opt/bin/subl"
  else
    tar -xf "${SUBLIME_TEXT_FILENAME}" -C "${OUTPUT_FOLDER}"
    ln -f -s "${OUTPUT_FOLDER}/sublime_text/sublime_text" "${HOME}/opt/bin/subl"
  fi

  rm -rf "${SUBLIME_TEXT_FILENAME}"
}

sublime_merge_install() {
  if [[ ${#} -ne 1 ]]; then
    var_error "Usage sublime_merge_install SUBLIME_MERGE_VERSION"
    return 1
  fi

  local SUBLIME_MERGE_VERSION="${1}"
  shift

  local FILENAME_SUFFIX
  FILENAME_SUFFIX="$(normalized_arch "amd64" "arm" "arm64").tar.xz"

  local OUTPUT_FOLDER="${HOME}/opt/"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    OUTPUT_FOLDER="${HOME}/Applications"
    FILENAME_SUFFIX="mac.zip"
    rm -rf "${OUTPUT_FOLDER}/Sublime Merge.app"
  fi

  local SUBLIME_MERGE_FILENAME="sublime_merge_build_${SUBLIME_MERGE_VERSION}_${FILENAME_SUFFIX}"
  curl --disable --silent --show-error --location --max-time 300 --remote-name "https://download.sublimetext.com/${SUBLIME_MERGE_FILENAME}"

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    unzip -d "${OUTPUT_FOLDER}" -o "${SUBLIME_MERGE_FILENAME}"
    ln -f -s "${OUTPUT_FOLDER}/Sublime Merge.app/Contents/SharedSupport/bin/smerge" "${HOME}/opt/bin/smerge"
  else
    tar -xf "${SUBLIME_MERGE_FILENAME}" -C "${OUTPUT_FOLDER}"
    ln -f -s "${OUTPUT_FOLDER}/sublime_merge/sublime_merge" "${HOME}/opt/bin/smerge"
  fi

  rm -rf "${SUBLIME_MERGE_FILENAME}"
}

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
