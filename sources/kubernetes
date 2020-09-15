#!/usr/bin/env bash

if command -v kubectl >/dev/null 2>&1; then
  __kube_ps1() {
    # preserve exit status
    local exit="${?}"

    if [[ -n ${KUBE_PS1:-} ]]; then
      printf " ☸️ %s" "$(kubectl config current-context)"
    fi

    return "${exit}"
  }

  if command -v fzf >/dev/null 2>&1; then
    kube() {
      if [[ ${#} -eq 0 ]] && [[ -n ${KUBE_PS1:-} ]]; then
        unset KUBE_PS1
        return
      fi

      export KUBE_PS1="true"

      get_kube_restart() {
        cat \
          <(kubectl get deployments --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/deployment/" + .name') \
          <(kubectl get daemonsets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/daemonset/" + .name') \
          <(kubectl get statefulsets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/statefulset/" + .name') |
          fzf --height 20 --ansi --reverse -1 -q "${1:-}"
      }

      get_kube_log() {
        cat \
          <(kubectl get deployments --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/deployment/" + .name') \
          <(kubectl get daemonsets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/daemonset/" + .name') \
          <(kubectl get statefulsets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/statefulset/" + .name') \
          <(kubectl get jobs --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/job/" + .name') |
          fzf --height 20 --ansi --reverse -1 -q "${1:-}"
      }

      get_kube_service() {
        kubectl get services --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/" + .name' | fzf --height 20 --ansi --reverse -1 -q "${1:-}"
      }

      get_kube_info() {
        cat \
          <(kubectl get deployments --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/deployment/" + .name') \
          <(kubectl get daemonsets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/daemonset/" + .name') \
          <(kubectl get statefulsets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/statefulsets/" + .name') \
          <(kubectl get cronjobs --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/cronjob/" + .name') \
          <(kubectl get jobs --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/job/" + .name') \
          <(kubectl get pods --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/pod/" + .name') \
          <(kubectl get configmaps --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/configmap/" + .name') \
          <(kubectl get secrets --all-namespaces -o=json | jq -r '.items[].metadata | .namespace + "/secret/" + .name') |
          fzf --height 20 --ansi --reverse -1 -q "${1:-}"
      }

      local ACTION="${1:-}"
      shift 1

      case ${ACTION} in
      "restart")
        IFS='/' read -r -a parts <<<"$(get_kube_restart "${*}")"
        if [[ -n ${parts[0]:-} ]]; then
          kubectl -n "${parts[0]}" rollout restart "${parts[1]}" "${parts[2]}"
        fi
        ;;

      "log" | "logs")
        IFS='/' read -r -a parts <<<"$(get_kube_log "${*}")"
        if [[ -n ${parts[0]:-} ]]; then
          local PODS_LABELS
          PODS_LABELS="$(kubectl -n "${parts[0]}" get "${parts[1]}" "${parts[2]}" -o json | jq -r '.spec.selector.matchLabels | to_entries[] | .key + "=" + .value' | paste -sd, -)"

          printf "%bTailing log for %s where labels are %b%s%b\n" "${BLUE}" "${parts[0]}/${parts[1]}/${parts[2]}" "${YELLOW}" "${PODS_LABELS}" "${RESET}"
          kubectl -n "${parts[0]}" logs --ignore-errors --prefix --max-log-requests=12 --all-containers=true --selector "${PODS_LABELS}" -f
        fi
        ;;

      "forward")
        IFS='/' read -r -a parts <<<"$(get_kube_service "${*}")"

        if [[ -n ${parts[0]:-} ]]; then
          local KUBE_PORT
          KUBE_PORT="$(kubectl -n "${parts[0]}" get services "${parts[1]}" -o=json | jq -r '.spec.ports[] | (.port|tostring) + "/" + .protocol' | fzf --height 20 --ansi --reverse -1 -q "${2:-}")"

          if [[ -n ${KUBE_PORT:-} ]]; then
            IFS='/' read -r -a ports <<<"${KUBE_PORT}"
            printf "%bForwarding %s from 4000 to %s%b\n" "${BLUE}" "${parts[0]}/${parts[1]}" "${ports[0]}" "${RESET}"
            kubectl -n "${parts[0]}" port-forward "services/${parts[1]}" "4000:${ports[0]}"
          fi
        fi
        ;;

      "info")
        IFS='/' read -r -a parts <<<"$(get_kube_info "${*}")"

        if [[ -n ${parts[0]:-} ]]; then
          kubectl -n "${parts[0]}" get "${parts[1]}" "${parts[2]}" -o yaml
        fi
        ;;

      "watch")
        kubectl get pods -A -w
        ;;

      "ns")
        local KUBE_NAMESPACE
        KUBE_NAMESPACE="$(kubectl get namespaces -o=json | jq -r '.items[].metadata.name' | fzf --height 20 --ansi --reverse -1 -q "${*}")"
        kubectl config set-context --current --namespace="${KUBE_NAMESPACE}"
        ;;

      *)
        kubectl config get-contexts -o name | fzf --height 20 --ansi --reverse -1 -q "${ACTION}" | xargs kubectl config use-context
        ;;
      esac
    }

    [[ -n ${BASH} ]] && complete -W "restart logs forward watch ns" -o default -o bashdefault kube
  fi

fi
