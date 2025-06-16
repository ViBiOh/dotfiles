#!/usr/bin/env bash

if ! command -v fzf >/dev/null 2>&1 || ! command -v yq >/dev/null 2>&1 || ! command -v kubectl >/dev/null 2>&1; then
  return
fi

export TMP_CONTEXT_LOCATION="${HOME}/.kube/contexts"

kube_clean_contexts() {
  rm -rf "${TMP_CONTEXT_LOCATION}"
}

kube() {
  local YELLOW='\033[33m'
  local BLUE='\033[0;34m'
  local RESET='\033[0m'

  history -s "${FUNCNAME[0]} ${*}"

  _kube_print_and_run() {
    printf -- "%b%s%b\n" "${YELLOW}" "${*}" "${RESET}" 1>&2
    history -s "${*}"
    eval "${*}"
  }

  _kube_info() {
    printf -- "%b%b %b\n" "${BLUE}" "${*}" "${RESET}" 1>&2
  }

  _kube_warning() {
    printf -- "%b%b %b\n" "${YELLOW}" "${*}" "${RESET}" 1>&2
  }

  local KUBECTL_COMMAND=("kubectl")
  local KUBECTL_CONTEXT=()
  declare -a KUBECTL_CONTEXTS

  while [[ ${1-} =~ ^--context ]]; do
    if [[ ${1-} =~ ^--context= ]]; then
      KUBECTL_CONTEXTS+=("${1}")

      if [[ ${#KUBECTL_CONTEXT} -eq 0 ]]; then
        KUBECTL_CONTEXT+=("${1}")
      fi

      shift
    else
      KUBECTL_CONTEXTS+=("--context=${2}")

      if [[ ${#KUBECTL_CONTEXT} -eq 0 ]]; then
        KUBECTL_CONTEXT+=("--context=${2}")
      fi

      shift 2
    fi
  done

  local RESOURCE_NAMESPACE="${KUBE_NS:-}"

  OPTIND=0
  while getopts ":n:" option; do
    case "${option}" in
    n)
      RESOURCE_NAMESPACE="${OPTARG}"
      ;;
    :)
      printf -- "option -%s requires a value\n" "${OPTARG}" 1>&2
      return 1
      ;;
    \?)
      printf -- "option -%s is invalid\n" "${OPTARG}" 1>&2
      return 2
      ;;
    esac
  done

  shift $((OPTIND - 1))

  local RESOURCE_TYPE
  local RESOURCE_NAME

  _kube_resources() {
    local RESOURCE="${1-}"
    local QUERY="${2-}"

    if [[ -n ${RESOURCE} ]] && [[ -z ${QUERY} ]]; then
      QUERY="${RESOURCE}"
      RESOURCE=""
    fi

    local RESOURCE_NAMESPACE_QUERY="--all-namespaces"
    if [[ -n ${RESOURCE_NAMESPACE} ]]; then
      RESOURCE_NAMESPACE_QUERY="--namespace=${RESOURCE_NAMESPACE}"
    fi

    if [[ -z ${RESOURCE} ]]; then
      RESOURCE="deployments.apps"
    fi

    local YAML_QUERY='.items[] | (.kind | downcase) + "/" + .metadata.namespace + "/" + .metadata.name'

    if [[ ${RESOURCE} == "ns" || ${RESOURCE} =~ ^namespaces? ]]; then
      YAML_QUERY='.items[] | (.kind | downcase) + "//" + .metadata.name'
    fi

    local KUBE_RESOURCE
    KUBE_RESOURCE="$("${KUBECTL_COMMAND[@]}" get "${RESOURCE}" "${RESOURCE_NAMESPACE_QUERY}" --output=yaml | yq eval "${YAML_QUERY}" | fzf --select-1 --query="${QUERY}")"

    RESOURCE_TYPE="$(printf '%s' "${KUBE_RESOURCE}" | awk -F '/' '{ print $1 }')"
    RESOURCE_NAMESPACE="$(printf '%s' "${KUBE_RESOURCE}" | awk -F '/' '{ print $2 }')"
    RESOURCE_NAME="$(printf '%s' "${KUBE_RESOURCE}" | awk -F '/' '{ print $3 }')"

    if [[ -n ${RESOURCE_NAMESPACE} ]]; then
      RESOURCE_NAMESPACE="--namespace=${RESOURCE_NAMESPACE}"
    fi
  }

  _kube_pod_labels() {
    if [[ ${RESOURCE_TYPE} =~ ^cronjobs? ]]; then
      printf -- "job-name in (%s)" "$("${KUBECTL_COMMAND[@]}" get jobs "${RESOURCE_NAMESPACE}" --output yaml | OWNER_NAME="${RESOURCE_NAME}" yq eval '.items[] | select(.metadata.ownerReferences[].name == strenv(OWNER_NAME)) | .metadata.name' | paste -sd, -)"
    elif [[ ${RESOURCE_TYPE} =~ ^jobs? ]]; then
      printf -- "job-name=%s" "${RESOURCE_NAME}"
    elif [[ ${RESOURCE_TYPE} =~ ^(daemonset|deployment|statefulset)s? ]]; then
      "${KUBECTL_COMMAND[@]}" get "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}" --output=yaml | yq eval '.spec.selector.matchLabels | to_entries | .[] | .key + "=" + .value' | paste -sd, -
    else
      "${KUBECTL_COMMAND[@]}" get "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}" --output=yaml | yq eval '.metadata.labels | to_entries | .[] | .key + "=" + .value' | paste -sd, -
    fi
  }

  _kube_help() {
    _kube_info "Usage: kube [--context=<name>...?] [options?] ACTION"

    _kube_info "\nPossibles options are\n"
    _kube_info " - -n Narrow resource search to given namespace (default search in all namespaces)"

    _kube_info "\nPossibles actions are                            | args\n"
    _kube_info " - context  | Switch context                      | <context name>"
    _kube_info " - desc     | Describe an object                  | <object type or deployment name> [object name]"
    _kube_info " - diff     | Run diff against multiple contexts  | <object type or deployment name> [object name]"
    _kube_info " - edit     | Edit an object                      | <object type or deployment name> [object name]"
    _kube_info " - env      | Generate .env file from deployments | <deployment name> [container name]"
    _kube_info " - exec     | Execute a command in a pod          | <object type or deployment name> [object name] [-c <container name>] [-t for tty] <any commands... default to /bin/bash>"
    _kube_info " - forward  | Port-forward to a service           | <service name> [exposed port number] (default 4000) [service port number]"
    _kube_info " - help     | Print this help                     |"
    _kube_info " - image    | Print image name                    | <deployment name>"
    _kube_info " - info     | Print yaml output of an object      | <object type or deployment name> [object name]"
    _kube_info " - log      | Tail logs                           | <object type or deployment name> [object name] <any additionnals args...>"
    _kube_info " - ns       | Change default namespace            | <namespace name>"
    _kube_info " - restart  | Perform a restart of pods           | <object type or deployment name> [object name]"
    _kube_info " - rollback | Undo a rollout                      | <object type or deployment name> [object name]"
    _kube_info " - scale    | Scale a replicable                  | <object type or deployment name> [object name] <factor>"
    _kube_info " - top      | Run top command                     | pod|node <object type or deployment name for pod filtering> [object name]"
    _kube_info " - watch    | Watch pods                          | <object type or deployment name> <object name> <any additionnals args...>"
    _kube_info " - *        | Call kubectl directly               | <any additionnals 'kubectl' args...>"
  }

  local ACTION
  if [[ ${#} -gt 0 ]]; then
    ACTION="${1}"
    shift
  fi

  if [[ ${ACTION} != "context" ]] && [[ ${#KUBECTL_CONTEXT} -eq 0 ]] && [[ $(yq eval '.contexts | length' "${KUBECONFIG:-${HOME}/.kube/config}") -gt 1 ]]; then
    local CURRENT_CONTEXT
    CURRENT_CONTEXT="$(yq eval '.current-context' "${KUBECONFIG:-${HOME}/.kube/config}")"

    local CONTEXTS
    CONTEXTS="$(yq eval '.contexts[].name' "${KUBECONFIG:-${HOME}/.kube/config}" | fzf --prompt="Contexts: " --multi --query "^${CURRENT_CONTEXT}$" --bind 'load:select-all+clear-query')"

    for context in ${CONTEXTS}; do
      KUBECTL_CONTEXTS+=("--context=${context}")

      if [[ ${#KUBECTL_CONTEXT} -eq 0 ]]; then
        KUBECTL_CONTEXT+=("--context=${context}")
      fi
    done
  fi

  if [[ ${#KUBECTL_CONTEXT} -ne 0 ]]; then
    KUBECTL_COMMAND+=("${KUBECTL_CONTEXT[@]}")
  fi

  case ${ACTION} in
  "context")
    local CONTEXT
    CONTEXT="$(yq eval '.contexts[].name' "${KUBECONFIG:-${HOME}/.kube/config}" | fzf --select-1 --query="${1-}")"

    if [[ -n ${CONTEXT-} ]]; then
      if [[ "$(yq eval '.current-context' "${KUBECONFIG:-${HOME}/.kube/config}")" == "${CONTEXT}" ]]; then
        _kube_info "Already on context '${CONTEXT}'"
        return
      fi

      if [[ -n ${TMUX-} ]]; then
        local CONTEXT_FILENAME
        CONTEXT_FILENAME="$(printf '%s' "${CONTEXT}" | md5)"

        if ! [[ -e "${TMP_CONTEXT_LOCATION}/${CONTEXT_FILENAME}" ]]; then
          mkdir -p "${TMP_CONTEXT_LOCATION}"
          cp "${KUBECONFIG:-${HOME}/.kube/config}" "${TMP_CONTEXT_LOCATION}/${CONTEXT_FILENAME}"
        fi

        export KUBECONFIG="${TMP_CONTEXT_LOCATION}/${CONTEXT_FILENAME}"
        tmux setenv KUBECONFIG "${KUBECONFIG}"
      fi

      _kube_print_and_run kubectl config use-context "${CONTEXT}"
    fi
    ;;

  "desc" | "describe")
    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      _kube_print_and_run "${KUBECTL_COMMAND[@]}" describe "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}"
    fi
    ;;

  "diff")
    if [[ ${#KUBECTL_CONTEXTS[@]} -lt 2 ]]; then
      _kube_warning "Diff only work with multiple contexts"
      return 1
    fi

    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      local QUERY="."
      if [[ ${RESOURCE_TYPE} =~ secrets? ]]; then
        QUERY=".data[] |= @base64d"
      fi

      declare -a DIFF_ARGS
      for context in "${KUBECTL_CONTEXTS[@]}"; do
        if [[ ${context} =~ ^--context= ]]; then
          DIFF_ARGS+=("<(kubectl ${context} get ${RESOURCE_TYPE} --namespace ${RESOURCE_NAMESPACE} ${RESOURCE_NAME} --output=yaml | yq eval --prettyPrint '\"${context}\", ${QUERY}')")
        elif ! [[ ${context} =~ ^--context ]]; then
          DIFF_ARGS+=("<(kubectl --context ${context} get ${RESOURCE_TYPE} --namespace ${RESOURCE_NAMESPACE} ${RESOURCE_NAME} --output=yaml | yq eval --prettyPrint '\"${context}\", ${QUERY}')")
        fi
      done

      eval "vimdiff -R ${DIFF_ARGS[*]}"
    fi
    ;;

  "edit")
    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      _kube_print_and_run "${KUBECTL_COMMAND[@]}" edit "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}"
    fi
    ;;

  "env")
    local FIRST=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      FIRST="${1}"
      shift
    fi

    local SECOND=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      SECOND="${1}"
      shift
    fi

    _kube_resources "${FIRST}" "${SECOND}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      if command -v kmux >/dev/null 2>&1; then
        _kube_print_and_run kmux "${KUBECTL_CONTEXTS[@]}" "${RESOURCE_NAMESPACE}" env "${RESOURCE_TYPE}" "${RESOURCE_NAME}" "${@}"
      else
        _kube_warning "env is only available if you have github.com/ViBiOh/kmux in your PATH"
        return 1
      fi
    fi
    ;;

  "exec")
    local FIRST=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      FIRST="${1}"
      shift
    fi

    local SECOND=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^[-/] ]]; then
      SECOND="${1}"
      shift
    fi

    _kube_resources "${FIRST}" "${SECOND}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      local EXTRA_OPTIONS
      local CONTAINER_SELECTED=0

      OPTIND=0
      while getopts ":c:t" option; do
        case "${option}" in
        c)
          EXTRA_OPTIONS+=" --container ${OPTARG}"
          CONTAINER_SELECTED=1
          ;;
        t)
          EXTRA_OPTIONS+=" --tty"
          ;;
        :)
          printf -- "option -%s requires a value\n" "${OPTARG}" 1>&2
          return 1
          ;;
        \?)
          printf -- "option -%s is invalid\n" "${OPTARG}" 1>&2
          return 2
          ;;
        esac
      done

      shift $((OPTIND - 1))

      if [[ ${CONTAINER_SELECTED} -eq 0 ]]; then
        local POD_GETTER_ARG="${RESOURCE_NAME}"
        local POD_CONTAINER_QUERY="."

        if ! [[ ${RESOURCE_TYPE} =~ pods? ]]; then
          POD_GETTER_ARG=" --selector $("${KUBECTL_COMMAND[@]}" get "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}/${RESOURCE_NAME}" --output yaml | yq '.spec.selector.matchLabels | to_entries | map(.key + "=" + .value) | join(",")')"
          POD_CONTAINER_QUERY=".items[0]"
        fi

        local CONTAINER_SELECTION
        CONTAINER_SELECTION="$("${KUBECTL_COMMAND[@]}" get "${RESOURCE_NAMESPACE}" pods ${POD_GETTER_ARG} --output yaml | yq "${POD_CONTAINER_QUERY}.spec.containers.[].name" | fzf --select-1 --prompt="Container: ")"

        if [[ -n ${CONTAINER_SELECTION:-} ]]; then
          EXTRA_OPTIONS+=" --container ${CONTAINER_SELECTION}"
        fi
      fi

      _kube_print_and_run "${KUBECTL_COMMAND[@]}" exec "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}/${RESOURCE_NAME}" ${EXTRA_OPTIONS} --stdin -- "${@-/bin/bash}"
    fi

    ;;

  "forward")
    _kube_resources "services" "${1:- }"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      shift 1

      local LOCAL_PORT="${1:-}"
      if [[ -z ${LOCAL_PORT-} ]] || [[ ${LOCAL_PORT:-} =~ ^- ]]; then
        LOCAL_PORT="4000"
      else
        shift 1
      fi

      local KUBE_PORT="${1:-}"
      if [[ -z ${KUBE_PORT-} ]] || [[ ${KUBE_PORT:-} =~ ^- ]]; then
        KUBE_PORT=""
      else
        shift 1
      fi

      if [[ -z ${KUBE_PORT:-} ]]; then
        KUBE_PORT="$("${KUBECTL_COMMAND[@]}" get "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}" --output=yaml | yq eval '.spec.ports[] | .targetPort' | fzf --select-1 --prompt="Port: ")"
      fi

      if [[ -n ${KUBE_PORT-} ]]; then
        if command -v kmux >/dev/null 2>&1; then
          _kube_print_and_run kmux "${KUBECTL_CONTEXTS[@]}" "${RESOURCE_NAMESPACE}" port-forward "${RESOURCE_TYPE}" "${RESOURCE_NAME}" "${LOCAL_PORT}:${KUBE_PORT}" "${@}"
        else
          printf -- "%bForwarding %s from %s to %s%b\n" "${BLUE}" "${RESOURCE_TYPE}/${RESOURCE_NAMESPACE%--namespace=}/${RESOURCE_NAME}" "${LOCAL_PORT}" "${KUBE_PORT}" "${RESET}"
          _kube_print_and_run "${KUBECTL_COMMAND[@]}" port-forward "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}/${RESOURCE_NAME}" --address "127.0.0.1" "${LOCAL_PORT}:${KUBE_PORT}"
        fi
      fi
    fi
    ;;

  "help")
    _kube_help
    ;;

  "image" | "images")
    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      if command -v kmux >/dev/null 2>&1; then
        _kube_print_and_run kmux "${KUBECTL_CONTEXTS[@]}" "${RESOURCE_NAMESPACE}" image "${RESOURCE_TYPE}" "${RESOURCE_NAME}"
      else
        _kube_print_and_run "${KUBECTL_COMMAND[@]}" get "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}" --output=yaml \| yq eval '.spec.template.spec.containers[].image'
      fi
    fi
    ;;

  "info")
    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      local QUERY="."
      if [[ ${RESOURCE_TYPE} =~ secrets? ]]; then
        QUERY=".data[] |= @base64d"
      fi

      _kube_print_and_run "${KUBECTL_COMMAND[@]}" get "${RESOURCE_TYPE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_NAME}" --output=yaml \| yq eval --prettyPrint "'${QUERY}'"
    fi
    ;;

  "log" | "logs")
    local FIRST=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      FIRST="${1}"
      shift
    fi

    local SECOND=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      SECOND="${1}"
      shift
    fi

    _kube_resources "${FIRST}" "${SECOND}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      local PODS_LABELS
      PODS_LABELS="$(_kube_pod_labels)"

      local KUBE_CONTAINER
      KUBE_CONTAINER="$("${KUBECTL_COMMAND[@]}" get pods "${RESOURCE_NAMESPACE}" --selector="${PODS_LABELS}" --output=yaml | yq eval '.items[].spec.containers[].name' | sort -u | fzf --select-1 --prompt="Container: ")"
      if [[ -n ${KUBE_CONTAINER:-} ]]; then
        KUBE_CONTAINER="--container=${KUBE_CONTAINER}"
      fi

      if [[ ${RESOURCE_TYPE} =~ ^(cronjob|daemonset|deployment|job|pod|namespace|service|node|statefulset)s? ]] && command -v kmux >/dev/null 2>&1; then
        _kube_print_and_run "kmux ${KUBECTL_CONTEXTS[*]} ${RESOURCE_NAMESPACE} log ${RESOURCE_TYPE} ${RESOURCE_NAME} --since=24h ${KUBE_CONTAINER} ${*}"
      else

        printf -- "%bTailing logs for %b%s%b where labels are %b%s%b\n" "${BLUE}" "${GREEN}" "${RESOURCE_TYPE}/${RESOURCE_NAMESPACE#--namespace=}/${RESOURCE_NAME}" "${BLUE}" "${YELLOW}" "${PODS_LABELS}" "${RESET}"

        _kube_print_and_run "${KUBECTL_COMMAND[*]} logs ${RESOURCE_NAMESPACE} --ignore-errors --prefix --selector=${PODS_LABELS} --follow --since=24h ${KUBE_CONTAINER} ${*}"
      fi
    fi
    ;;

  "ns")
    "${KUBECTL_COMMAND[@]}" get namespaces --output=yaml | yq eval '.items[].metadata.name' | fzf --select-1 --query="${1-}" | xargs "${KUBECTL_COMMAND[@]}" config set-context --current --namespace
    ;;

  "restart")
    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      if command -v kmux >/dev/null 2>&1; then
        _kube_print_and_run kmux "${KUBECTL_CONTEXTS[@]}" "${RESOURCE_NAMESPACE}" restart "${RESOURCE_TYPE}" "${RESOURCE_NAME}"
      else
        if [[ ${RESOURCE_TYPE} =~ ^jobs? ]]; then
          _kube_print_and_run "${KUBECTL_COMMAND[@]}" get "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}" "${RESOURCE_NAME}" --output yaml \| yq eval 'del(.spec.selector)' \| yq eval 'del(.spec.template.metadata.labels)' \| "${KUBECTL_COMMAND[@]}" replace --force --filename -
        else
          _kube_print_and_run "${KUBECTL_COMMAND[@]}" rollout restart "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}" "${RESOURCE_NAME}"
        fi
      fi
    fi

    ;;

  "rollback")
    _kube_resources "${@}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      if [[ ${#KUBECTL_CONTEXTS} -eq 0 ]]; then
        _kube_print_and_run kubectl rollout undo "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}" "${RESOURCE_NAME}"
      else
        for context in "${KUBECTL_CONTEXTS[@]}"; do
          _kube_print_and_run kubectl "${context}" rollout undo "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}" "${RESOURCE_NAME}"
        done
      fi
    fi

    ;;

  "scale")
    local FIRST=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      FIRST="${1}"
      shift
    fi

    local SECOND=""
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      SECOND="${1}"
      shift
    fi

    local KUBE_SCALE_FACTOR="1"
    if [[ ${SECOND:-} =~ [0-9]+(\.[0-9])? ]]; then
      KUBE_SCALE_FACTOR="${SECOND}"
      SECOND=""
    elif [[ -n ${1-} ]]; then
      KUBE_SCALE_FACTOR="${1:-1}"
      shift
    fi

    _kube_resources "${FIRST}" "${SECOND}"

    if [[ -n ${RESOURCE_NAME-} ]]; then
      if command -v kmux >/dev/null 2>&1; then
        _kube_print_and_run kmux "${KUBECTL_CONTEXTS[@]}" "${RESOURCE_NAMESPACE}" scale "${RESOURCE_TYPE}" "${RESOURCE_NAME}" --factor "${KUBE_SCALE_FACTOR}" "${@}"
      else
        for context in "${KUBECTL_CONTEXTS[@]}"; do
          local CURRENT_SCALE
          CURRENT_SCALE="$(kubectl "${context}" get "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}" "${RESOURCE_NAME}" --output yaml | yq eval '.spec.replicas')"

          if [[ ${CURRENT_SCALE:-} -eq 0 ]]; then
            CURRENT_SCALE=1
          fi

          local WANTED_SCALE
          WANTED_SCALE="$(printf "%f * %f" "${CURRENT_SCALE}" "${KUBE_SCALE_FACTOR}" | bc | sed -e 's|\.0*$||;s|\.[0-9]*$| + 1|' | bc)"

          _kube_print_and_run kubectl "${context}" scale --replicas "${WANTED_SCALE}" "${RESOURCE_NAMESPACE}" "${RESOURCE_TYPE}" "${RESOURCE_NAME}"
        done
      fi
    fi

    ;;

  "top")
    local EXTRA_ARGS=()
    local TOP_SUB_COMMAND="pod"

    if [[ -n ${1-} ]] && [[ ${1-} =~ ^(pod|node)s?$ ]]; then
      TOP_SUB_COMMAND="${1}"
      shift
    fi

    if [[ ${TOP_SUB_COMMAND} =~ ^pods? ]]; then
      local FIRST=""
      if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
        FIRST="${1}"
        shift
      fi

      local SECOND=""
      if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
        SECOND="${1}"
        shift
      fi

      if [[ -n ${FIRST:-} ]]; then
        _kube_resources "${FIRST}" "${SECOND}"

        local EXTRA_ARGS=()

        if [[ -n ${RESOURCE_NAME-} ]]; then
          local PODS_LABELS
          PODS_LABELS="$(_kube_pod_labels)"

          if [[ -n ${PODS_LABELS-} ]]; then
            EXTRA_ARGS+=("--selector=${PODS_LABELS}" "${RESOURCE_NAMESPACE}")
          fi
        fi
      fi
    fi

    if [[ ${#KUBECTL_CONTEXTS} -eq 0 ]]; then
      _kube_print_and_run "kubectl" top "${TOP_SUB_COMMAND}" "${@}" "${EXTRA_ARGS[@]}"
    else
      for context in "${KUBECTL_CONTEXTS[@]}"; do
        _kube_print_and_run "kubectl" "${context}" top "${TOP_SUB_COMMAND}" "${@}" "${EXTRA_ARGS[@]}"
      done
    fi
    ;;

  "watch")
    if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
      local FIRST=""
      FIRST="${1}"
      shift

      local SECOND=""
      if [[ -n ${1-} ]] && ! [[ ${1-} =~ ^- ]]; then
        SECOND="${1}"
        shift
      fi

      _kube_resources "${FIRST}" "${SECOND}"
    fi

    local EXTRA_ARGS=()

    if [[ -n ${RESOURCE_NAME-} ]]; then
      local PODS_LABELS
      PODS_LABELS="$(_kube_pod_labels)"

      if [[ -n ${PODS_LABELS-} ]]; then
        EXTRA_ARGS+=("--selector=${PODS_LABELS}" "${RESOURCE_NAMESPACE}")
      fi
    else
      EXTRA_ARGS+=("--namespace=${RESOURCE_NAMESPACE}")
    fi

    if command -v kmux >/dev/null 2>&1; then
      _kube_print_and_run kmux "${KUBECTL_CONTEXTS[@]}" watch "${EXTRA_ARGS[@]}" "${@}"
    else
      _kube_print_and_run "${KUBECTL_COMMAND[@]}" get pods --watch "${EXTRA_ARGS[@]}" "${@}"
    fi
    ;;

  *)
    _kube_print_and_run "${KUBECTL_COMMAND[@]}" "${ACTION}" "${@}"

    return 1
    ;;
  esac
}

_fzf_complete_kube() {
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "context desc diff edit env exec forward image info log ns restart rollback top watch --context --namespace -n" -- "${COMP_WORDS[COMP_CWORD]}")
    return
  fi

  local NAMESPACE_SCOPE="--all-namespaces"
  if [[ -n ${KUBE_NS:-} ]]; then
    NAMESPACE_SCOPE="--namespace=${KUBE_NS}"
  fi

  case ${COMP_WORDS[COMP_CWORD - 1]} in
  "context" | "--context")
    FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
      kubectl config get-contexts --output name
    )
    ;;

  "forward")
    FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
      kubectl get services "${NAMESPACE_SCOPE}" --output=yaml | yq eval '.items[].metadata.name'
    )
    ;;

  "desc" | "describe" | "diff" | "edit" | "env" | "exec" | "image" | "images" | "info" | "log" | "logs" | "restart" | "rollback" | "top" | "watch")
    FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
      kubectl get deployments.app "${NAMESPACE_SCOPE}" --output=yaml | yq eval '.items[].metadata.name'
    )
    ;;

  "ns" | "-n" | "--namespace")
    FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
      kubectl get namespaces --output=yaml | yq eval '.items[].metadata.name'
    )
    ;;
  esac
}

[[ -n ${BASH} ]] && complete -F _fzf_complete_kube -o default -o bashdefault kube
