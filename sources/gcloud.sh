#!/usr/bin/env bash

if [[ -f "${HOME}/opt/google-cloud-sdk/path.bash.inc" ]]; then
  source "${HOME}/opt/google-cloud-sdk/path.bash.inc"
fi

if ! command -v gcloud >/dev/null 2>&1; then
  return
fi

if [[ -f "${HOME}/opt/google-cloud-sdk/completion.bash.inc" ]]; then
  source "${HOME}/opt/google-cloud-sdk/completion.bash.inc"
fi

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export GOOGLE_CONTAINER_REGISTRIES=("gcr.io" "eu.gcr.io" "us.gcr.io")

gcloud_auth() {
  gcloud auth login --update-adc
  gcloud config unset compute/region
  gcloud config set project "$(gcloud projects list | grep dev | awk '{print $1}')"

  if command -v docker >/dev/null 2>&1; then
    for registry in "${GOOGLE_CONTAINER_REGISTRIES[@]}"; do
      gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "https://${registry}"
    done
  fi
}

gcloud_account() {
  local GCLOUD_ACCOUNT
  GCLOUD_ACCOUNT="$(gcloud auth list --format 'value(account)' | fzf --height=20 --ansi --reverse --select-1 --query="${1-}")"

  if [[ -n ${GCLOUD_ACCOUNT:-} ]]; then
    gcloud config set account "${GCLOUD_ACCOUNT}"
  fi
}

gcloud_kube_import() {
  local GCLOUD_PROJECT
  GCLOUD_PROJECT="$(gcloud projects list --format json | gcloud projects list --format json | jq --raw-output '.[] | .projectId + " " + .name' | fzf --height=20 --ansi --reverse --select-1 --query="${1-}")"

  if [[ -z ${GCLOUD_PROJECT:-} ]]; then
    return 1
  fi

  local GCLOUD_PROJECT_ID
  GCLOUD_PROJECT_ID="$(printf '%s' "${GCLOUD_PROJECT}" | awk '{ print $1 }')"

  local GCLOUD_PROJECT_NAME
  GCLOUD_PROJECT_NAME="$(printf '%s' "${GCLOUD_PROJECT}" | cut -f 2- -d ' ' | tr '[:upper:]' '[:lower:]' | sed 's| |-|')"

  local GCLOUD_CLUSTER
  GCLOUD_CLUSTER="$(gcloud --project "${GCLOUD_PROJECT_ID}" container clusters list --format json | jq --raw-output '.[] | .name + "@" + .zone' | fzf --height=20 --ansi --reverse --select-1 --query="${2-}")"

  if [[ -z ${GCLOUD_CLUSTER-} ]]; then
    return 1
  fi

  local CLUSTER_NAME
  CLUSTER_NAME="$(printf '%s' "${GCLOUD_CLUSTER}" | awk -F '@' '{ print $1 }')"
  local CLUSTER_ZONE
  CLUSTER_ZONE="$(printf '%s' "${GCLOUD_CLUSTER}" | awk -F '@' '{ print $2 }')"

  if [[ -n ${CLUSTER_NAME:-} ]]; then
    gcloud --project "${GCLOUD_PROJECT_ID}" container clusters get-credentials "${CLUSTER_NAME}" --zone "${CLUSTER_ZONE}"
    kubectl config rename-context "$(kubectl config current-context)" "${GCLOUD_PROJECT_NAME}_${CLUSTER_NAME}"

    if [[ -n ${2:-} ]]; then
      kubectl config set-context --current --namespace "${3:-default}"
    fi
  fi
}
