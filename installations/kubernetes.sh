#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.kube"
}

install() {
  if [[ -e "${HOME}/.kube/config" ]]; then
    chmod 0600 "${HOME}/.kube/config"
  fi

  local KUBERNETES_VERSION
  KUBERNETES_VERSION="$(curl --disable --silent --show-error --location --max-time 30 "https://storage.googleapis.com/kubernetes-release/release/stable.txt")"

  curl_to_binary "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/$(normalized_os)/$(normalized_arch "amd64" "arm" "arm64")/kubectl" "kubectl"
  kubectl completion bash >"${HOME}/opt/completions/kubectl-completion.sh"

  # renovate: datasource=github-releases depName=helm/helm
  local HELM_VERSION="v3.18.4"

  archive_to_binary "https://get.helm.sh/helm-${HELM_VERSION}-$(normalized_os)-$(normalized_arch "amd64" "arm" "arm64").tar.gz" "$(normalized_os)-$(normalized_arch "amd64" "arm" "arm64")/helm"
  if command -v helm >/dev/null 2>&1; then
    helm completion bash >"${HOME}/opt/completions/helm-completion.sh"
  else
    var_error "helm was not found in path. Please run 'helm completion bash >'${HOME}/opt/completions/helm-completion'"
  fi

  # renovate: datasource=github-releases depName=fluxcd/flux2
  local FLUX_VERSION="v2.6.4"
  archive_to_binary "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_$(normalized_os)_$(normalized_arch "amd64" "arm" "arm64").tar.gz" "flux"
  flux completion bash >"${HOME}/opt/completions/flux-completion.sh"

  # renovate: datasource=github-releases depName=bitnami-labs/sealed-secrets
  local KUBESEAL_VERSION="v0.30.0"
  archive_to_binary "https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION#v}-$(normalized_os)-$(normalized_arch "amd64" "arm" "arm64").tar.gz" "kubeseal"

  # renovate: datasource=github-releases depName=ViBiOh/kmux
  local KMUX_VERSION="v0.14.2"
  archive_to_binary "https://github.com/ViBiOh/kmux/releases/download/${KMUX_VERSION}/kmux_$(normalized_os)_$(normalized_arch "" "arm" "arm64").tar.gz" "kmux"
  kmux completion bash >"${HOME}/opt/completions/kmux-completion.sh"
}

credentials() {
  if ! command -v pass >/dev/null 2>&1 || ! [[ -d ${PASSWORD_STORE_DIR:-${HOME}/.password-store} ]]; then
    return
  fi

  extract_secret "infra/kube" ".kube/config"
}
