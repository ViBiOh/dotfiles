#!/usr/bin/env bash

codeberg_token() {
  meta_check "pass"

  pass_get "dev/codeberg" "token"
}

codeberg_http_init() {
  meta_check "var" "http"

  http_init_client --header "Authorization: token $(codeberg_token)"
}

codeberg_configure() {
  meta_check "var" "http"

  if [[ ${#} -ne 1 ]]; then
    var_red "Usage: codeberg_configure CODEBERG_REPOSITORY"
    return 1
  fi

  local CODEBERG_REPOSITORY="${1}"

  codeberg_http_init

  http_request --request "PATCH" "https://codeberg.org/api/v1/repos/${CODEBERG_REPOSITORY}" --header "Content-Type: application/json" --data "$(json '{
    allow_merge_commits: false,
    allow_squash_merge: false,
    allow_rebase: true,

    default_branch: "main",
    default_delete_branch_after_merge: true,

    has_actions: true,
    has_issues: true,
    has_pull_requests: true,

    has_projects: false,
    has_packages: false,
    has_releases: false,
    has_wiki: false
  }')"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to edit ${CODEBERG_REPOSITORY}"
    http_reset
    return 1
  fi

  codeberg_set_variable "${CODEBERG_REPOSITORY}" "DOCKER_NAMESPACE" "vibioh"
  codeberg_set_variable "${CODEBERG_REPOSITORY}" "DOCKER_REGISTRY" "rg.fr-par.scw.cloud"

  codeberg_set_secret "${CODEBERG_REPOSITORY}" "SCW_ACCES_KEY" "$(pass_get "dev/scaleway" "registry_access_key")"
  codeberg_set_secret "${CODEBERG_REPOSITORY}" "SCW_SECRET_KEY" "$(pass_get "dev/scaleway" "registry_secret_key")"

  http_reset
}

codeberg_set_variable() {
  if [[ ${#} -ne 3 ]]; then
    var_red "Usage: codeberg_set_variable CODEBERG_REPOSITORY VARIABLE_NAME VARIABLE_VALUE"
    return 1
  fi
  codeberg_http_init

  local CODEBERG_REPOSITORY="${1}"
  shift

  local VARIABLE_NAME="${1}"
  shift

  local VARIABLE_VALUE="${1}"
  shift

  local VARIABLE_METHOD="PUT"

  http_request "https://codeberg.org/api/v1/repos/${CODEBERG_REPOSITORY}/actions/variables/${VARIABLE_NAME}"
  if [[ ${HTTP_STATUS} == "404" ]]; then
    VARIABLE_METHOD="POST"
  fi

  http_request \
    --request "${VARIABLE_METHOD}" \
    --header "Content-Type: application/json" \
    --data "$(json --arg "value" "${VARIABLE_VALUE}" '{value: $value}')" \
    "https://codeberg.org/api/v1/repos/${CODEBERG_REPOSITORY}/actions/variables/${VARIABLE_NAME}"
  if [[ ${HTTP_STATUS} != "201" ]] && [[ ${HTTP_STATUS} != "204" ]]; then
    http_handle_error "Unable to set ${VARIABLE_NAME} variable of ${CODEBERG_REPOSITORY}"
    http_reset
    return 1
  fi

  http_reset
}

codeberg_set_secret() {
  if [[ ${#} -ne 3 ]]; then
    var_red "Usage: codeberg_set_secret CODEBERG_REPOSITORY SECRET_NAME SECRET_VALUE"
    return 1
  fi

  codeberg_http_init

  local CODEBERG_REPOSITORY="${1}"
  shift

  local SECRET_NAME="${1}"
  shift

  local SECRET_VALUE="${1}"
  shift

  http_request \
    --request "PUT" \
    --header "Content-Type: application/json" \
    --data "$(json --arg "value" "${SECRET_VALUE}" '{data: $value}')" \
    "https://codeberg.org/api/v1/repos/${CODEBERG_REPOSITORY}/actions/secrets/${SECRET_NAME}"
  if [[ ${HTTP_STATUS} != "201" ]] && [[ ${HTTP_STATUS} != "204" ]]; then
    http_handle_error "Unable to set ${SECRET_NAME} secret of ${CODEBERG_REPOSITORY}"
    http_reset
    return 1
  fi

  http_reset
}

codeberg_set_hook() {
  if [[ ${#} -ne 2 ]]; then
    var_red "Usage: codeberg_set_hook CODEBERG_REPOSITORY HOOK_URL"
    return 1
  fi
  codeberg_http_init

  local CODEBERG_REPOSITORY="${1}"
  shift

  local HOOK_URL="${1}"
  shift

  http_request "https://codeberg.org/api/v1/repos/${CODEBERG_REPOSITORY}/hooks"
  if [[ ${HTTP_STATUS} == "404" ]]; then
    VARIABLE_METHOD="POST"
  fi

  http_request \
    --request "${VARIABLE_METHOD}" \
    --header "Content-Type: application/json" \
    --data "$(json --arg "url" "${HOOK_URL}" '{
      branch_filter: "main",
      events: ["push"],
      config: {
        url: $url
      },
      type: "forgejo"
    }')" \
    "https://codeberg.org/api/v1/repos/${CODEBERG_REPOSITORY}/hooks"
  if [[ ${HTTP_STATUS} != "201" ]]; then
    http_handle_error "Unable to set ${VARIABLE_NAME} hook of ${CODEBERG_REPOSITORY}"
    http_reset
    return 1
  fi

  http_reset
}
