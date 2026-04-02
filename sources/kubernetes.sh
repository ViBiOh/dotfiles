#!/usr/bin/env bash

if ! command -v kubectl >/dev/null 2>&1; then
  return
fi

kube_ssh_tunnel() {
  ssh_forward_local 6443 6443 "${KUBERNETES_MASTER}"
}

kubernetes_shell() {
  local CONTEXT
  CONTEXT="$(kubectl config get-contexts -o name | fzf --height=20 --ansi --reverse --select-1 --query="${1-}" --prompt "Context: ")"

  if [[ -z ${CONTEXT-} ]]; then
    return 1
  fi

  var_info "Context: ${CONTEXT}"

  local NAMESPACE
  NAMESPACE="$(kubectl --context "${CONTEXT}" get namespaces --output=yaml | yq eval '.items[].metadata.name' | fzf --height=20 --ansi --reverse --select-1 --query="${2-}" --prompt "Namespace: ")"

  if [[ -z ${NAMESPACE-} ]]; then
    return 1
  fi

  var_info "Namespace: ${NAMESPACE}"

  local POD_NAME
  POD_NAME="$(whoami)-shell"

  if [[ $(kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" get pod "${POD_NAME}" 2>/dev/null | wc -l) -eq 0 ]]; then
    var_info "Creating a shell pod"

    local IMAGE
    IMAGE="$(printf -- "alpine\nubuntu\nnode\npython\nother" | fzf --height=20 --ansi --reverse --select-1 --query="${3-}" --prompt "Image: ")"

    if [[ -z ${IMAGE:-} ]] || [[ ${IMAGE:-} == "other" ]]; then
      IMAGE="${4-}"

      if [[ -z ${IMAGE:-} ]]; then
        var_read "Image name: " IMAGE
      fi
    fi

    cat <<EOF | kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: kubernetes-shell
    app.kubernetes.io/owner: $(whoami)
    app.kubernetes.io/instance: ${POD_NAME}
spec:
  containers:
    - name: shell
      image: ${IMAGE}
      command:
        - /bin/sh
      args:
        - "-c"
        - "tail -f /dev/null"
EOF

    var_info "Waiting for Running condition..."
    kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" wait --for=jsonpath='{.status.phase}'=Running "pod/${POD_NAME}"
  fi

  var_info "Connecting to the ${POD_NAME} pod..."
  kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" exec "${POD_NAME}" --stdin --tty -- "/bin/sh" || true

  var_info "Deleting the ${POD_NAME} pod..."
  kubectl --context "${CONTEXT}" --namespace "${NAMESPACE}" delete pod "${POD_NAME}"
}

kubernetes_postgres_backup() {
  meta_check "var"

  local POSTGRES_USER
  var_shift_or_read POSTGRES_USER "${1-}"
  shift || true

  local POSTGRES_DB
  var_shift_or_read POSTGRES_DB "${1-}"
  shift || true

  local BACKUP_FILE
  var_shift_or_read BACKUP_FILE "${1-}"
  shift || true

  local CONTEXT
  CONTEXT="$(kubectl config get-contexts --output name | fzf --height=20 --ansi --reverse --select-1 --query="${1-}" --prompt "Context: ")"

  if [[ -z ${CONTEXT-} ]]; then
    return 1
  fi

  local POSTGRES_POD
  POSTGRES_POD="$(kubectl --context "${CONTEXT}" get pods --output name | fzf --height=20 --ansi --reverse --prompt "Pod: ")"

  if [[ -z ${POSTGRES_POD-} ]]; then
    return 1
  fi

  if [[ -n ${POSTGRES_POD:-} ]]; then
    kubectl --context "${CONTEXT}" exec --tty "${POSTGRES_POD}" -- pg_dump --format=c --user "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" >"${BACKUP_FILE}"
  fi
}

kubernetes_postgres_restore() {
  meta_check "var"

  local POSTGRES_USER
  var_shift_or_read POSTGRES_USER "${1-}"
  shift || true

  local POSTGRES_DB
  var_shift_or_read POSTGRES_DB "${1-}"
  shift || true

  local CONTEXT
  CONTEXT="$(kubectl config get-contexts --output name | fzf --height=20 --ansi --reverse --select-1 --query="${1-}" --prompt "Context: ")"

  if [[ -z ${CONTEXT-} ]]; then
    return 1
  fi

  local BACKUP_FILE
  BACKUP_FILE="$(
    FZF_DEFAULT_COMMAND='rg --files --sortr path 2> /dev/null' fzf --height=20 --ansi --reverse --query "${POSTGRES_DB}"
  )"

  if [[ -z ${BACKUP_FILE-} ]]; then
    return 1
  fi

  local POSTGRES_POD
  POSTGRES_POD="$(kubectl --context "${CONTEXT}" get pods --output name | fzf --height=20 --ansi --reverse --prompt "Pod: ")"

  if [[ -z ${POSTGRES_POD:-} ]]; then
    return 1
  fi

  if [[ -n ${POSTGRES_POD:-} ]]; then
    kubectl --context "${CONTEXT}" exec --tty --stdin "${POSTGRES_POD}" -- pg_restore --format=c --user "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <"${BACKUP_FILE}"
  fi
}

if command -v yq >/dev/null 2>&1; then
  __kube_ps1() {
    # preserve exit status
    local exit="${?}"

    local CONFIG_FILE="${KUBECONFIG:-${HOME}/.kube/config}"
    if ! [[ -e ${CONFIG_FILE} ]]; then
      return "${exit}"
    fi

    local K8S_CONTEXT
    K8S_CONTEXT="$(yq eval '.current-context as $context | .contexts[] | select(.name == $context) | .context.cluster + "/" + (.context.namespace // "default")' "${CONFIG_FILE}")"

    if [[ -n ${K8S_CONTEXT:-} ]]; then
      printf -- " 🐳 %s" "${K8S_CONTEXT}"
    fi

    return "${exit}"
  }
fi

if command -v helm >/dev/null 2>&1 && command -v delta >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && command -v yq >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
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

    var_print_and_run printf '%s' "${CONTENT}" | kubeseal --raw --from-file=/dev/stdin --namespace "${NAMESPACE}" --name "${NAME}" --scope "${SCOPE}" --cert "${CERT}" | pbcopy
  }
fi
