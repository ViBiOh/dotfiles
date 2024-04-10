#!/usr/bin/env bash

if [[ -e "${HOME}/.fzf.bash" ]]; then
  source "${HOME}/.fzf.bash"
fi

if ! command -v fzf >/dev/null 2>&1; then
  return
fi

export FZF_DEFAULT_OPTS="--height=20 --ansi --reverse"

if command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files 2> /dev/null'
  export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
fi

if command -v git >/dev/null 2>&1; then
  grip() {
    fzf --ansi --reverse --tiebreak=index --no-sort --no-hscroll --preview 'f() { set -- $(echo -- "$@" | grep -o "[a-f0-9]\{7\}"); [ $# -eq 0 ] || git show --color=always $1; }; f {}'
  }
fi

if command -v jq >/dev/null 2>&1; then
  fzjq() {
    printf '' | fzf --query '.' --height 50% --print-query --preview-window up:99% --preview "jq --color-output ''{q}'' ${1}"
  }
fi

if command -v pass >/dev/null 2>&1; then
  _fzf_complete_pass() {
    FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
      local PASS_DIR=${PASSWORD_STORE_DIR:-${HOME}/.password-store}
      find "${PASS_DIR}" -name "*.gpg" -print | sed -e "s|${PASS_DIR}/\(.*\)\.gpg$|\1|"
    )
  }

  [[ -n ${BASH} ]] && complete -F _fzf_complete_pass -o default -o bashdefault pass

  passfor() {
    if [[ ${#} -ne 1 ]]; then
      var_red "Usage: passfor PASS_NAME"
      return 1
    fi

    local PASS_NAME="${1}"
    shift

    pass_get "${PASS_NAME}" "password" | pbcopy

    if command -v pass >/dev/null 2>&1 && [[ -e "${PASSWORD_STORE_DIR:-${HOME}/.password-store}/${PASS_NAME}.gpg" ]] && [[ "$(pass show "${PASS_NAME}" | grep --count "^otpauth:")" -eq 1 ]]; then
      read -s -r -p "  Press enter for otp"
      printf "\n"

      pass otp -c "${PASS_NAME}"
    fi
  }

  [[ -n ${BASH} ]] && complete -F _fzf_complete_pass -o default -o bashdefault passfor

  passfull() {
    if [[ ${#} -ne 1 ]]; then
      var_red "Usage: passfull PASS_NAME"
      return 1
    fi

    local PASS_NAME="${1}"
    shift

    pass_get "${PASS_NAME}" "login" | pbcopy
    printf "Copied login of %s to clipboard\n" "${PASS_NAME}"
    read -s -r -p "Press enter for password"
    printf "\n"

    passfor "${PASS_NAME}"
  }

  [[ -n ${BASH} ]] && complete -F _fzf_complete_pass -o default -o bashdefault passfull
fi

if command -v make >/dev/null 2>&1; then
  _fzf_complete_make() {
    # From https://unix.stackexchange.com/a/230050
    FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(make -pqr 2>/dev/null | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A)print A[i]}' | grep --invert-match Makefile | sort --unique)
  }
  [[ -n ${BASH} ]] && complete -F _fzf_complete_make -o default -o bashdefault make
fi

if command -v ssh >/dev/null 2>&1; then
  _fzf_complete_ssh_notrigger() {
    FZF_COMPLETION_TRIGGER="" _fzf_host_completion
  }

  [[ -n ${BASH} ]] && complete -F _fzf_complete_ssh_notrigger -o default -o bashdefault ssh
fi

if command -v pgcli >/dev/null 2>&1; then
  _fzf_complete_pgcli() {
    if [[ ! -f ${PGPASSFILE-${HOME}/.pgpass} ]]; then
      return
    fi

    FZF_COMPLETION_TRIGGER="" _fzf_complete --ansi --select-1 "${@}" < <(
      local comment=""

      while IFS=":" read -r host port db user pass; do
        if [[ ! ${host} =~ ^\s*# ]] && [[ ! ${host} =~ ^\s*$ ]]; then
          printf "host: %b%s%b port: %b%s%b db: %b%s%b user: %b%s%b %b%s%b\n" "${BLUE}" "${host}" "${RESET}" "${YELLOW}" "${port}" "${RESET}" "${RED}" "${db}" "${RESET}" "${GREEN}" "${user}" "${RESET}" "${BLUE}" "${comment}" "${RESET}"
          comment=""
        elif [[ ${host} =~ ^\s*# ]]; then
          comment="${host}"
        fi
      done <"${PGPASSFILE-${HOME}/.pgpass}"
    )
  }

  _fzf_complete_pgcli_post() {
    sed -E 's|host: ([^:]*) port: ([^:]*) db: ([^:]*) user: ([^:]*)|\1 \2 \3 \4|g' |
      awk '{if ($1 != "*") { print "-h " $1; } if ($2 != "*") { print "-p " $2; } if ($4 != "*") { print "-U " $4; } if ($3 != "*") { print $3; }}'
  }

  [[ -n ${BASH} ]] && complete -F _fzf_complete_pgcli -o default -o bashdefault pgcli
fi

if command -v mycli >/dev/null 2>&1; then
  _fzf_complete_mycli() {
    if [[ ! -f ${HOME}/.myclirc ]]; then
      return
    fi

    FZF_COMPLETION_TRIGGER="" _fzf_complete --ansi --select-1 "${@}" < <(cat "${HOME}/.myclirc" | grep --extended-regexp '^[a-zA-Z0-9_-]+\s*=\s*mysql://' | awk '{print $1}')
  }

  _fzf_complete_mycli_post() {
    awk '{printf("-d %s", $1)}'
  }

  [[ -n ${BASH} ]] && complete -F _fzf_complete_mycli -o default -o bashdefault mycli
fi
