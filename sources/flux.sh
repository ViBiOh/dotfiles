#!/usr/bin/env bash

flux_hook() {
  local KUBE_CONTEXT
  KUBE_CONTEXT="$(kubectl config get-contexts -o name | fzf --height=20 --ansi --reverse --select-1 --query="${1-}" --prompt "Context: ")"

  if [[ -z ${KUBE_CONTEXT} ]]; then
    return 1
  fi

  local FLUX_RECEIVER
  FLUX_RECEIVER="$(kubectl --context "${KUBE_CONTEXT}" get receivers --all-namespaces --output json |
    jq -r -c '.items[].metadata | .namespace + "/" + .name' |
    fzf --height=20 --ansi --reverse --select-1 --query="${2-}" --prompt "Receiver: ")"

  if [[ -z ${FLUX_RECEIVER} ]]; then
    return 1
  fi

  kubectl --context "${CONTEXT}" get receivers \
    --namespace "$(printf '%s' "${FLUX_RECEIVER}" | awk -F '/' '{ print $1 }')" \
    "$(printf '%s' "${FLUX_RECEIVER}" | awk -F '/' '{ print $2 }')" \
    --output json | jq -r -c ".status.webhookPath"
}
