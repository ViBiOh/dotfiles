#!/usr/bin/env bash

if ! command -v git >/dev/null 2>&1; then
  return
fi

if [[ -e "${DOTFILES_SOURCES_DIR}/../scripts/meta" ]]; then
  source "${DOTFILES_SOURCES_DIR}/../scripts/meta" && meta_init "git"
fi

if command -v delta >/dev/null 2>&1; then
  export GIT_PAGER='delta --dark'
fi

...() {
  cd "$(git_root)" || return 1
}

# https://blog.gitbutler.com/git-tips-3-really-large-repositories/
# https://www.git-tower.com/blog/git-performance/
git_large_repos() {
  git config index.threads true
  git config feature.manyFiles true
  git config core.fsmonitor true
  git config fetch.writeCommitGraph true
  git commit-graph write --reachable
}

git_large_repos_status() {
  git fsmonitor--daemon status
}

git_repository() {
  if ! git_is_inside; then
    return
  fi

  local REMOTE_URL
  REMOTE_URL="$(git remote get-url --push "$(git remote show | head -1)")"

  if [[ ${REMOTE_URL} =~ ^.*@(.*)[:/](.*)/(.*)$ ]]; then
    jq --null-input --compact-output \
      --arg url "${BASH_REMATCH[1]}" \
      --arg owner "${BASH_REMATCH[2]}" \
      --arg name "${BASH_REMATCH[3]%.git}" \
      '{
          url: $url,
          owner: $owner,
          name: $name
        }'
  fi
}

git_release() {
  meta_check "var" "git" "http"

  if ! git_is_inside; then
    var_warning "not inside a git tree"
    return 1
  fi

  var_info "Identifying semver"

  local LAST_TAG
  LAST_TAG="$(git_last_tag)"

  local VERSION_REF
  local PREVIOUS_REF

  if [[ -n ${LAST_TAG:-} ]]; then
    VERSION_REF="$(git log --no-merges --invert-grep --grep "\[skip ci\] Automated" --color --pretty=format:'%Cred%h%Creset%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' "HEAD...${LAST_TAG}" | fzf --height=20 --ansi --reverse | awk '{printf("%s", $1)}')"
    var_read PREVIOUS_REF "$(git tag --sort=-creatordate | grep --invert-match "${VERSION_REF}" | head -1)"
  else
    PREVIOUS_REF="HEAD^1"
    VERSION_REF="HEAD"
  fi

  local CHANGELOG
  CHANGELOG=$(git_changelog "${VERSION_REF}" "${PREVIOUS_REF}")
  printf -- "%bCHANGELOG:%b\n\n%s%b\n\n" "${YELLOW}" "${GREEN}" "${CHANGELOG}" "${RESET}"

  local VERSION_TYPE="patch"
  if [[ ${CHANGELOG} =~ \#\ BREAKING\ CHANGES ]]; then
    VERSION_TYPE="major"
  elif [[ ${CHANGELOG} =~ \#\ Features ]]; then
    VERSION_TYPE="minor"
  fi

  printf -- "%bRelease seems to be a %b%s%b\n" "${BLUE}" "${YELLOW}" "${VERSION_TYPE}" "${RESET}"
  var_info "Specify explicit git tag or major|minor|patch for semver increment"
  local VERSION
  VERSION="$(printf -- "%bpatch\n%bminor\n%bmajor" "${GREEN}" "${YELLOW}" "${RED}" | fzf --height=20 --ansi --reverse)"

  local GIT_TAG
  GIT_TAG="$(version_semver "${VERSION}" "${VERSION_REF}" "quiet")"

  local REPOSITORY
  REPOSITORY="$(git_repository)"

  var_read REPOSITORY_NAME "$(printf "%s" "${REPOSITORY}" | jq -r '.owner + "/" + .name')"
  var_read RELEASE_NAME "${GIT_TAG}"

  var_info "Creating release ${RELEASE_NAME} for ${REPOSITORY_NAME}..."

  if [[ "$(printf "%s" "${REPOSITORY}" | jq -r '.url')" == "github.com" ]]; then
    github_create_release "${REPOSITORY_NAME}" "${RELEASE_NAME}" "${VERSION_REF}" "${CHANGELOG}"
  elif [[ "$(printf "%s" "${REPOSITORY}" | jq -r '.url')" == "codeberg.org" ]]; then
    codeberg_create_release "${REPOSITORY_NAME}" "${RELEASE_NAME}" "${VERSION_REF}" "${CHANGELOG}"
  else
    var_error "Unhandled repository type"
    var_warning "${REPOSITORY}"
  fi

  unset REPOSITORY_NAME
  unset RELEASE_NAME
}

git_hooks_toggle() {
  if [[ ${SCRIPTS_NO_GIT_HOOKS:-} == "true" ]]; then
    var_info "Git hooks enabled"
    unset SCRIPTS_NO_GIT_HOOKS
  else
    var_info "Git hooks disabled"
    export SCRIPTS_NO_GIT_HOOKS="true"
  fi
}

git_hooks_toggle_config() {
  if ! git_is_inside; then
    return
  fi

  local CONFIG_NAME="${1}"
  shift

  local TOGGLE_INVERTED="${1:-false}"
  shift

  if [[ $(git config "${CONFIG_NAME}") == "true" ]]; then
    if [[ ${TOGGLE_INVERTED} == "true" ]]; then
      var_info "Disabling ${CONFIG_NAME}"
    else
      var_info "Enabling ${CONFIG_NAME}"
    fi

    git config --unset "${CONFIG_NAME}"
  else
    if [[ ${TOGGLE_INVERTED} == "true" ]]; then
      var_info "Enabling ${CONFIG_NAME}"
    else
      var_info "Disabling ${CONFIG_NAME}"
    fi

    git config "${CONFIG_NAME}" "true"
  fi
}

git_hooks_no_yaml_format() {
  git_hooks_toggle_config "hooks.noYamlFormat"
}

git_hooks_no_md_format() {
  git_hooks_toggle_config "hooks.noMarkdownFormat"
}

git_hooks_bazelle_gazelle() {
  git_hooks_toggle_config "hooks.bazelleGazelle" "true"
}

git_hooks_json_sort() {
  git_hooks_toggle_config "hooks.jsonSort" "true"
}
