#!/usr/bin/env bash

declare -g AWS_EXEC_ACCOUNT

aws_exec() {
  if [[ -z ${AWS_ACCOUNTS:-} ]]; then
    "$(which aws)" "${@}"
    return
  fi

  if [[ -z ${AWS_EXEC_ACCOUNT:-} ]]; then
    AWS_EXEC_ACCOUNT="$(printf -- "%s\n" "${AWS_ACCOUNTS[@]}" | fzf --height=20 --ansi --reverse --select-1 --prompt "Profile: ")"
  fi

  if [[ -n ${AWS_EXEC_ACCOUNT} ]]; then
    var_print_and_run aws-vault exec "${AWS_EXEC_ACCOUNT}" -- "$(which aws)" "${@}"
  fi
}

aws_unset() {
  AWS_EXEC_ACCOUNT=""
}

alias aws=aws_exec

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
