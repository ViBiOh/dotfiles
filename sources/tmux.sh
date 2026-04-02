#!/usr/bin/env bash

tmux_is_inside() {
  if [[ -z ${TMUX-} ]]; then
    return 1
  fi

  return 0
}

tmux_split_cmd() (
  if ! tmux_is_inside; then
    printf -- "not inside a tmux\n"
    return 1
  fi

  tmux split-window -hd -c "$(pwd)" -t "${TMUX_PANE}" "bash --rcfile <(echo '. ~/.bash_profile;${*}')" && tmux select-layout tiled
)

tmux_batch() {
  local BATCH_ACTION="echo"
  local MAX_PARALLEL=4
  local QUIET="false"
  local ITEMS=()

  OPTIND=0
  while getopts ":a:i:n:q" option; do
    case "${option}" in
    a)
      BATCH_ACTION="${OPTARG}"
      ;;
    i)
      IFS=',' read -r -a ITEMS <<<"${OPTARG}"
      ;;
    n)
      MAX_PARALLEL="${OPTARG}"
      ;;
    q)
      QUIET="true"
      ;;
    :)
      printf -- "option -%s requires a value\n" "${OPTARG}" >&2
      return 1
      ;;
    \?)
      printf -- "option -%s is invalid\n" "${OPTARG}" >&2
      return 2
      ;;
    esac
  done

  shift $((OPTIND - 1))

  if [[ ${#ITEMS[@]} -ne 0 ]]; then
    ITEMS_LIST="$(printf -- "\t- %s\n" "${ITEMS[@]}")"
    printf -- "%bItems are:\n%b%s%b\n" "${BLUE}" "${YELLOW}" "${ITEMS_LIST}" "${RESET}"

    for item in "${ITEMS[@]}"; do
      ${BATCH_ACTION} "${item}"
    done

    if [[ ${QUIET} == "true" ]]; then
      tmux kill-pane -t "${TMUX_PANE}"
    fi
    return
  fi

  if [[ ${#} -lt 1 ]]; then
    var_red "Usage: tmux_batch FIND_COMMAND"
    return 1
  fi

  local index=0
  declare -A spread

  while IFS= read -r -d '' item; do
    spread["$((index % MAX_PARALLEL))"]+="${item},"
    index="$((index + 1))"
  done < <(${1-})

  (
    index=0
    for items in "${spread[@]}"; do
      local ARGS=("tmux_batch" "-i" "${items[*]%,}" "-a" "${BATCH_ACTION}")
      if [[ ${QUIET} == "true" ]]; then
        ARGS+=("-q")
      fi

      tmux_split_cmd "${ARGS[@]}"
    done
  )
}
