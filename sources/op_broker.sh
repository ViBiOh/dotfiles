#!/usr/bin/env bash

export OP_BROKER_DIR="${HOME}/.local/state/op_broker"
export OP_BROKER_PID_FILE="${OP_BROKER_DIR}/daemon.pid"
export OP_BROKER_SOCKET="${OP_BROKER_DIR}/op.sock"
export OP_BROKER_HANDLER="${HOME}/.local/bin/op_broker"
export OP_BROKER_TIMEOUT="${OP_BROKER_TIMEOUT:-60}"

op_broker_running() {
  local pid

  if [[ ! -f ${OP_BROKER_PID_FILE} ]]; then
    return 1
  fi

  pid="$(<"${OP_BROKER_PID_FILE}")"

  if [[ -z ${pid} ]]; then
    return 1
  fi

  kill -0 "${pid}" >/dev/null 2>&1
}

op_broker_start() {
  if op_broker_running; then
    return 0
  fi

  if ! command -v op >/dev/null 2>&1 || ! command -v socat >/dev/null 2>&1 || [[ ! -x ${OP_BROKER_HANDLER} ]]; then
    return 1
  fi

  mkdir -p "${OP_BROKER_DIR}"
  chmod 700 "${OP_BROKER_DIR}"
  rm -f "${OP_BROKER_SOCKET}"

  # Without -t, socat closes the connection 0.5s after the client half closes, which kills the handler while the 1Password prompt is still open.
  # Background inside a subshell so the interactive shell never adds it to its job table.
  (
    nohup socat -t "${OP_BROKER_TIMEOUT}" "UNIX-LISTEN:${OP_BROKER_SOCKET},fork,mode=600" "EXEC:${OP_BROKER_HANDLER}" >/dev/null 2>&1 &
    printf -- '%s' "${!}" >"${OP_BROKER_PID_FILE}"
  )
}

op_broker_stop() {
  if op_broker_running; then
    kill "$(<"${OP_BROKER_PID_FILE}")"
  fi

  rm -f "${OP_BROKER_PID_FILE}" "${OP_BROKER_SOCKET}"
}

workspaces_daemon_restart() {
  op_broker_stop
  op_broker_start
}
