#!/usr/bin/env bash

if ! command -v n >/dev/null 2>&1; then
  return
fi

export N_PREFIX="${HOME}/opt"

if ! command -v node >/dev/null 2>&1; then
  return
fi

export PATH="${HOME}/opt/node/bin:${PATH}"
alias npmi='npm install --ignore-scripts'

npm_headless_login() {
  if [[ ${#} -ne 3 ]]; then
    var_error "Usage npm_headless_login: NPM_REGISTRY NPM_USERNAME NPM_PASSWORD"
    return 1
  fi

  local NPM_REGISTRY="${1}"
  shift
  local NPM_USERNAME="${1}"
  shift
  local NPM_PASSWORD="${1}"
  shift

  local PAYLOAD
  PAYLOAD="$(jq --null-input --compact-output \
    --arg username "${NPM_USERNAME}" \
    --arg password "${NPM_PASSWORD}" \
    '{ name: $username, password: $password }')"

  local NPM_TOKEN
  NPM_TOKEN="$(curl --disable --silent --show-error --location --max-time 10 --fail-with-body "https://${NPM_REGISTRY}/-/user/org.couchdb.user:${NPM_USERNAME}" --header "Accept: application/json" --header "Content-Type:application/json" --request PUT --data "${PAYLOAD}" | jq --raw-output '.token')"

  if [[ -z ${NPM_TOKEN} ]]; then
    return 1
  fi

  npm set "//${NPM_REGISTRY}/:_authToken=${NPM_TOKEN}"
}
