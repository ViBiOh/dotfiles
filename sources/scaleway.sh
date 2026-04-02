#!/usr/bin/env bash

scw_allow_ip() {
  meta_check "var" "http"

  local ZONE="${1:-fr-par-2}"
  shift 1 || true

  http_init_client
  http_request -4 "https://ifconfig.co/ip"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to get public IP"
    http_reset
    return 1
  fi

  local PUBLIC_IP
  PUBLIC_IP="$(cat "${HTTP_OUTPUT}")"

  printf "Public IP is %s\n" "${PUBLIC_IP}"

  http_init_client --header "X-Auth-Token: $(pass_get "dev/scaleway" "secret_key")"

  http_request "https://api.scaleway.com/instance/v1/zones/${ZONE}/security_groups/"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to find security group id"
    http_reset
    return 1
  fi

  local SECURITY_GROUP_ID
  SECURITY_GROUP_ID="$(jq --raw-output '.security_groups[] | .name + " - " +  .id' "${HTTP_OUTPUT}" | fzf --prompt="Security Group: " --query "${1:-}" --select-1 | awk '{print $3}')"

  rm "${HTTP_OUTPUT}"

  printf "Security group ID %s\n" "${SECURITY_GROUP_ID}"

  http_request "https://api.scaleway.com/instance/v1/zones/${ZONE}/security_groups/${SECURITY_GROUP_ID}/rules"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to find security rule id"
    http_reset
    return 1
  fi

  local SECURITY_GROUP_RULE_ID
  SECURITY_GROUP_RULE_ID="$(jq --raw-output '.rules[] | (.dest_port_from | tostring) + " - " +  .id' "${HTTP_OUTPUT}" | fzf --prompt="Port: " --query "${1:-}" --select-1 | awk '{print $3}')"
  rm "${HTTP_OUTPUT}"

  printf "Security rule ID %s\n" "${SECURITY_GROUP_RULE_ID}"

  http_request --request PATCH --header "Content-Type: application/json" "https://api.scaleway.com/instance/v1/zones/${ZONE}/security_groups/${SECURITY_GROUP_ID}/rules/${SECURITY_GROUP_RULE_ID}" \
    --data "$(json "{ip_range: \"${PUBLIC_IP}/32\"}")"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to update security rule"
    http_reset
    return 1
  fi

  http_reset

  rm "${HTTP_OUTPUT}"
}

scw_registry_clean() {
  meta_check "var" "http"

  http_init_client --header "X-Auth-Token: $(pass_get "dev/scaleway" "registry_secret_key")"

  var_read SCW_REGION "fr-par"

  http_request "https://api.scaleway.com/registry/v1/regions/${SCW_REGION}/images"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to list images"
    http_reset
    return 1
  fi

  declare -A IMAGES
  while IFS=, read -r id name; do
    IMAGES["${id}"]="${name}"
  done < <(jq --raw-output '.images[] | .id + "," + .name' "${HTTP_OUTPUT}")

  _scw_delete_tag() {
    var_info "Delete tag ${1}:${2}"

    http_request --request DELETE "https://api.scaleway.com/registry/v1/regions/${SCW_REGION}/tags/${3}"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to delete tag"
      return 1
    fi
  }

  for id in "${!IMAGES[@]}"; do
    http_request "https://api.scaleway.com/registry/v1/regions/${SCW_REGION}/images/${id}/tags"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to list tags for ${IMAGES[${id}]}"
      return 1
    fi

    local LAST_TIMESTAMP=""
    local LAST_TIMESTAMP_ID=""

    while IFS=, read -r tagID tagName; do
      if [[ ${tagName} =~ ^[a-f0-9]{7,8}($|-) ]]; then
        _scw_delete_tag "${IMAGES[${id}]}" "${tagName}" "${tagID}"
      elif [[ ${tagName} =~ ^[0-9]{12}$ ]]; then
        if [[ -z ${LAST_TIMESTAMP:-} ]]; then
          LAST_TIMESTAMP="${tagName}"
          LAST_TIMESTAMP_ID="${tagID}"
        elif [[ ${LAST_TIMESTAMP} -gt ${tagName} ]]; then
          _scw_delete_tag "${IMAGES[${id}]}" "${tagName}" "${tagID}"
        elif [[ ${LAST_TIMESTAMP} -lt ${tagName} ]]; then
          _scw_delete_tag "${IMAGES[${id}]}" "${LAST_TIMESTAMP}" "${LAST_TIMESTAMP_ID}"
          LAST_TIMESTAMP="${tagName}"
          LAST_TIMESTAMP_ID="${tagID}"
        fi
      fi
    done < <(jq --raw-output '.tags[] | .id + "," + .name' "${HTTP_OUTPUT}")
  done

  http_reset
}
