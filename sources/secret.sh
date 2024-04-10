#!/usr/bin/env bash

extract_secret() {
  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: extract_secret SECRET_NAME RELATIVE_PATH_FROM_HOME [REPLACE]"
    return 1
  fi

  if ! command -v pass >/dev/null 2>&1; then
    var_warning "pass not available for extracting secret"
    return
  fi

  local SECRET_NAME="${1}"
  shift
  local RELATIVE_PATH_FROM_HOME="${1}"
  shift
  local SECRET_REPLACE="${REPLACE:-true}"
  shift || true

  if [[ -z ${RELATIVE_PATH_FROM_HOME} ]]; then
    var_red "path from home is empty"
    return 1
  fi

  local SECRET_CONFIG_FILE="${HOME}/${RELATIVE_PATH_FROM_HOME}"

  mkdir -p "$(dirname "${SECRET_CONFIG_FILE}")"

  if [[ ${SECRET_REPLACE:-} == "true" ]]; then
    rm -f "${SECRET_CONFIG_FILE}"
  fi

  pass show "${SECRET_NAME}" >>"${SECRET_CONFIG_FILE}"
  chmod 600 "${SECRET_CONFIG_FILE}"
}
