#!/usr/bin/env bash

github() {
  meta_check "var" "http"

  http_init_client --header "Authorization: Bearer $(github_token)" --header "Accept: application/vnd.github+json" --header "X-GitHub-Api-Version: 2022-11-28"
  http_request "https://api.github.com${1}"

  if ! [[ ${HTTP_STATUS} =~ 2.. ]]; then
    http_handle_error
    return 1
  fi

  jq --raw-output "." "${HTTP_OUTPUT}"
  rm "${HTTP_OUTPUT}"
}
