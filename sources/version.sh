#!/usr/bin/env bash

version_bump() {
  if [[ -e package.json ]]; then
    var_print_and_run npx npm-check-updates -u
    npm install --ignore-scripts
    npm audit fix
  fi

  if [[ -e go.mod ]]; then
    local CURRENT_MODULE
    CURRENT_MODULE="$(go list -m)"

    local REGEX_FILTER="${1-}"
    var_read REGEX_FILTER ""

    for dep in $(go list -m -json all | jq --raw-output 'select(.Indirect != true) | .Path'); do
      if [[ ${dep} == "${CURRENT_MODULE}" ]]; then
        continue
      fi

      if [[ -n ${REGEX_FILTER:-} ]] && ! [[ ${dep} =~ ${REGEX_FILTER} ]]; then
        continue
      fi

      var_print_and_run go get -u "${dep}@latest"
    done

    go mod tidy -compat=1.17
    git diff go.mod
  fi

  if [[ -e provider.tf ]]; then
    var_print_and_run terraform init -upgrade
  fi
}

version_semver() {
  meta_check "var" "git"

  if ! git_is_inside; then
    var_warning "not inside a git tree"
    return 1
  fi

  local PREFIX="v"
  local MAJOR="0"
  local MINOR="0"
  local PATCH="0"

  local CURRENT_VERSION
  CURRENT_VERSION="$(git describe --tags --abbrev=0 2>/dev/null)"

  if [[ -n ${CURRENT_VERSION:-} ]]; then
    if ! [[ ${CURRENT_VERSION} =~ ([a-zA-Z]*)([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
      var_error "cannot parse existing version: ${CURRENT_VERSION}"
      return 2
    fi

    local PREFIX="${BASH_REMATCH[1]}"
    local MAJOR="${BASH_REMATCH[2]}"
    local MINOR="${BASH_REMATCH[3]}"
    local PATCH="${BASH_REMATCH[4]}"
  fi

  if [[ ${#} -lt 1 ]]; then
    var_info "Current version is: ${PREFIX}${MAJOR}.${MINOR}.${PATCH}"
    var_red "Usage: version_semver major|minor|patch [GIT_REF=HEAD] [quiet]"
    return 3
  fi

  local VERSION_TYPE="${1}"
  shift
  local GIT_REF="${1:-HEAD}"
  shift || true

  case "${VERSION_TYPE}" in
  "major")
    MAJOR="$((MAJOR + 1))"
    MINOR="0"
    PATCH="0"
    ;;

  "minor")
    MINOR="$((MINOR + 1))"
    PATCH="0"
    ;;

  "patch")
    PATCH="$((PATCH + 1))"
    ;;

  *)
    var_error "unknown version name: ${VERSION_TYPE}"
    return 4
    ;;
  esac

  local NEW_VERSION="${PREFIX}${MAJOR}.${MINOR}.${PATCH}"

  if [[ ${#} -lt 1 ]]; then
    git tag -m "${NEW_VERSION}" "${GIT_REF}"
    var_green "New version is: ${NEW_VERSION}"
  else
    printf -- "%s" "${NEW_VERSION}"
  fi
}
