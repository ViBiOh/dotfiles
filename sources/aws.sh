#!/usr/bin/env bash

aws_regions() {
  local ENDPOINTS
  ENDPOINTS="$(_aws_endpoints)"

  printf -- "%s" "${ENDPOINTS}" | jq -r '.partitions[].regions | keys[]'
}

aws_regions_no_service() {
  local ENDPOINTS
  ENDPOINTS="$(_aws_endpoints)"

  local SERVICE
  SERVICE="$(_aws_regions_service "${1-}")"

  if [[ $(printf -- "%s" "${ENDPOINTS}" | jq -r --arg service "${SERVICE}" '.partitions[].services.[$service] | select(.endpoints != null) | .endpoints | keys[] | select(. == "aws-global") | .' | wc -l) -eq 1 ]]; then
    printf -- "This is an aws-global endpoint\n"

    return
  fi

  printf -- "%s" "${ENDPOINTS}" | jq -r --arg service "${SERVICE}" '[.partitions[].regions | keys[]] - [.partitions[].services.[$service] | select(.endpoints != null) | .endpoints | keys[]]'
}

aws_regions_enpoints() {
  local ENDPOINTS
  ENDPOINTS="$(_aws_endpoints)"

  local SERVICE
  SERVICE="$(_aws_regions_service "${1-}")"

  printf -- "%s" "${ENDPOINTS}" | jq -r --arg service "${SERVICE}" '.partitions[].services.[$service] | select(.endpoints != null) | .endpoints'
}

_aws_endpoints() {
  curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/boto/botocore/develop/botocore/data/endpoints.json"
}

_aws_regions_service() {
  printf -- "%s" "${ENDPOINTS}" | jq -r '.partitions[].services | keys[]' | sort -u | fzf --select-1 --query="${1-}"
}
