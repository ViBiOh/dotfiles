#!/usr/bin/env bash

SSH_ENV="${HOME}/.ssh/environment"
unset SSH_AUTH_SOCK

ssh_forward_to_local() {
  meta_check "var"

  if [[ ${#} -lt 3 ]]; then
    var_red "Import remote port in local. Usage: ssh_forward_local REMOTE_PORT -> LOCAL_PORT SSH_PARTS..."
    return 1
  fi

  local REMOTE_PORT="${1}"
  shift
  local LOCAL_PORT="${1}"
  shift

  var_info "SSH Forward: REMOTE:${REMOTE_PORT} -> 127.0.0.1:${LOCAL_PORT}"
  var_print_and_run ssh -N -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" "${@}"
}

ssh_forward_to_remote() {
  meta_check "var"

  if [[ ${#} -lt 3 ]]; then
    var_red "Expose local port to remote: Usage: ssh_forward_remote LOCAL_PORT -> REMOTE_PORT SSH_PARTS..."
    return 1
  fi

  local LOCAL_PORT="${1}"
  shift
  local REMOTE_PORT="${1}"
  shift

  var_info "SSH Forward: 127.0.0.1:${LOCAL_PORT} -> REMOTE:${REMOTE_PORT}"
  var_print_and_run ssh -N -R "${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT}" "${@}"
}

ssh_proxy() {
  meta_check "var"

  if [[ ${#} -lt 1 ]]; then
    var_red "Start a SOCKS proxy on port 8080"
    return 1
  fi

  var_info "SSH SOCKS: 127.0.0.1:8080 -> ${1:-}"
  var_print_and_run ssh -C2qTnN -D 8080 "${1:-}"
}

[[ -n ${BASH} ]] && complete -F _fzf_complete_ssh_notrigger -o default -o bashdefault ssh_proxy

ssh_agent_running() {
  ps -p "${SSH_AGENT_PID-}" >/dev/null 2>&1
}

ssh_agent_stop() {
  if ssh_agent_running; then
    ssh-agent -k

    source <(sed 's|export|unset|' "${SSH_ENV}")
    rm -rf "${SSH_ENV:?}"
  fi
}

ssh_agent_start() {
  printf -- "Initializing new SSH agent...\n"

  touch "${SSH_ENV}"
  chmod 600 "${SSH_ENV}"

  ssh-agent | grep --invert-match "^echo" >"${SSH_ENV}"
  source "${SSH_ENV}"
}

ssh_agent_init() {
  ssh_agent_stop

  if [[ -d "${HOME}/.ssh/" ]]; then
    local AGENT_INITIALIZED="false"

    while IFS= read -r -d '' key; do
      if [[ -e ${key%.pub} ]]; then
        if [[ ${AGENT_INITIALIZED} == "false" ]]; then
          AGENT_INITIALIZED="true"
          ssh_agent_start
        fi

        ssh-add -k "${key%.pub}"
      fi
    done < <(find "${HOME}/.ssh" -type f -name '*.pub' -print0)
  fi
}

if [[ -f ${SSH_ENV-} ]]; then
  source "${SSH_ENV}"
fi

if ! ssh_agent_running && [[ $(type -t ssh_agent_init) == "function" ]]; then
  ssh_agent_init
fi
