#!/usr/bin/env bash

kube_ssh_tunnel() {
  ssh_forward_local 6443 6443 "${KUBERNETES_MASTER}"
}

if command -v kubectl >/dev/null 2>&1; then
  if command -v yq >/dev/null 2>&1; then
    __kube_ps1() {
      # preserve exit status
      local exit="${?}"

      local CONFIG_FILE="${KUBECONFIG:-${HOME}/.kube/config}"
      if ! [[ -e ${CONFIG_FILE} ]]; then
        return "${exit}"
      fi

      local K8S_CONTEXT
      K8S_CONTEXT="$(yq eval '.current-context as $context | .contexts[] | select(.name == $context) | .context.cluster + "/" + (.context.namespace // "default")' "${KUBECONFIG:-${HOME}/.kube/config}")"

      if [[ -n ${K8S_CONTEXT} ]]; then
        printf -- " ☸ %s" "${K8S_CONTEXT}"
      fi

      return "${exit}"
    }
  fi
fi

if command -v helm >/dev/null 2>&1 && command -v delta >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v yq >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
  helm_select_chart() {
    local CHART_REPOSITORY
    CHART_REPOSITORY="$(helm repo list --output json | jq --raw-output '.[].name' | fzf --select-1 --query="${1-}")"
    if [[ -z ${CHART_REPOSITORY} ]]; then
      return 1
    fi

    var_info "Repository: ${CHART_REPOSITORY}"

    local CHART_NAME
    CHART_NAME="$(helm search repo "${CHART_REPOSITORY}/" --output json | jq --raw-output '.[].name' | fzf --select-1 --query="${2-}")"
    if [[ -z ${CHART_NAME} ]]; then
      return 1
    fi

    var_info "Chart: ${CHART_NAME}"

    local CHART_VERSION
    CHART_VERSION="$(helm search repo "${CHART_NAME}" --output json --devel --versions | jq --raw-output '.[].version' | fzf --select-1 --query="${3-}")"

    if [[ -z ${CHART_VERSION} ]]; then
      return 1
    fi

    var_info "Version: ${CHART_VERSION}"

    printf -- "%s@%s" "${CHART_NAME}" "${CHART_VERSION}"
  }

  helm_delta() {
    local HELM_RELEASE
    HELM_RELEASE="$(helm list --all-namespaces --output yaml | yq eval '.[] | .namespace + "/" + .name' - | fzf --height=20 --ansi --reverse)"

    local NAMESPACE
    NAMESPACE="$(printf '%s' "${HELM_RELEASE}" | awk -F '/' '{ print $1 }')"
    local NAME
    NAME="$(printf '%s' "${HELM_RELEASE}" | awk -F '/' '{ print $2 }')"

    if [[ -z ${NAMESPACE-} ]] || [[ -z ${NAME-} ]]; then
      return 1
    fi

    var_info "Release: ${NAMESPACE}/${NAME}"

    local HELM_CHART
    HELM_CHART="$(helm_select_chart "" "" "")"

    local CHART
    CHART="$(printf '%s' "${HELM_CHART}" | awk -F '@' '{ print $1 }')"
    local VERSION
    VERSION="$(printf '%s' "${HELM_CHART}" | awk -F '@' '{ print $2 }')"

    if [[ -z ${CHART-} ]] || [[ -z ${VERSION-} ]]; then
      return 1
    fi

    extract_manifest() {
      yq eval '.manifest' - | yq eval --prettyPrint 'sortKeys(..)' -
    }

    local TEMP_FOLDER
    TEMP_FOLDER="$(mktemp -d)"

    helm status --output yaml --namespace "${NAMESPACE}" "${NAME}" | extract_manifest >"${TEMP_FOLDER}/${NAME}_helm.yaml"
    helm upgrade --output yaml --namespace "${NAMESPACE}" "${NAME}" "${CHART}" --version "${VERSION}" --debug --dry-run ${*} | extract_manifest >"${TEMP_FOLDER}/${NAME}_new.yaml"
    delta "${TEMP_FOLDER}/${NAME}_helm.yaml" "${TEMP_FOLDER}/${NAME}_new.yaml"
    rm -rf "${TEMP_FOLDER}"

    if var_confirm "Perform upgrade"; then
      var_print_and_run helm upgrade --namespace "${NAMESPACE}" "${NAME}" "${CHART}" --version "${VERSION}" "${@}"
    fi
  }

  helm_crds_manifests() {
    local HELM_CHART
    HELM_CHART="$(helm_select_chart "" "" "")"

    local CHART
    CHART="$(printf '%s' "${HELM_CHART}" | awk -F '@' '{ print $1 }')"
    local VERSION
    VERSION="$(printf '%s' "${HELM_CHART}" | awk -F '@' '{ print $2 }')"

    if [[ -z ${CHART-} ]] || [[ -z ${VERSION-} ]]; then
      return 1
    fi

    local CURRENT_DIR
    CURRENT_DIR="$(pwd)"

    (
      local TEMP_FOLDER
      TEMP_FOLDER="$(mktemp -d)"
      cd "${TEMP_FOLDER}" || false

      local CHART_BASENAME
      CHART_BASENAME="$(basename "${CHART}")"

      helm pull "${CHART}" --version "${VERSION}" --untar

      if [[ -d "${CHART_BASENAME}/crds/" ]]; then
        printf -- "%bCopying %b%s%b to current folder%b\n" "${BLUE}" "${YELLOW}" "$(find "${CHART_BASENAME}/crds" -type f -print0 | xargs -0 printf -- "%s, " | sed 's|, $||')" "${BLUE}" "${RESET}" 1>&2
        cp "${CHART_BASENAME}/crds/"* "${CURRENT_DIR}/"
      else
        var_warning "no crds/ folder in this chart, searching for definition..."
        rg -- "^kind: CustomResourceDefinition" "${CHART_BASENAME}/"
      fi

      rm -rf "${CHART_BASENAME}" "${TEMP_FOLDER}"
    )
  }
fi

if command -v kubeseal >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
  kubeseal_raw() {
    local NAMESPACE
    var_shift_or_read NAMESPACE "${1-}"
    shift || true

    local NAME
    var_shift_or_read NAME "${1-}"
    shift || true

    local CONTENT
    var_shift_or_read CONTENT "${1-}"
    shift || true

    local CERT=""
    CERT="$(rg --files --glob '*.{pem,crt}' | fzf --height=20 --ansi --reverse)"

    local SCOPE=""
    SCOPE="$(printf -- "strict\nnamespace-wide\ncluster-wide" | fzf --height=20 --ansi --reverse)"

    var_print_and_run " printf '%s' '${CONTENT}' | kubeseal --raw --from-file=/dev/stdin --namespace '${NAMESPACE}' --name '${NAME}' --scope '${SCOPE}' --cert '${CERT}' | pbcopy"
  }
fi
