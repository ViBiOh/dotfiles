#!/usr/bin/env bash

export GIT_PS1_SHOWDIRTYSTATE="true"
export GIT_PS1_STATESEPARATOR="|"
export GIT_PS1_SHOWSTASHSTATE="true"
export GIT_PS1_SHOWUNTRACKEDFILES="true"
export GIT_PS1_COMPRESSSPARSESTATE="true"

export PROMPT_DIRTRIM="3"

__ps1_previous_status() {
  if [[ ${?} -eq 0 ]]; then
    printf -- "%b✔%b" "${GREEN}" "${RESET}"
  else
    printf -- "%bx%b" "${RED}" "${RESET}"
  fi
}

PS1="${BLUE}\u${RESET}@${RED}\h${RESET} ${GREEN}\w${RESET}"
if [[ "$(type -t "__git_ps1")" == "function" ]]; then
  PS1+="${YELLOW}\$(__git_ps1)${RESET}"
fi

if [[ "$(type -t "__kube_ps1")" == "function" ]]; then
  PS1+="${BLUE}\$(__kube_ps1)${RESET}"
fi

if [[ "$(type -t "__terraform_ps1")" == "function" ]]; then
  PS1+="${PURPLE}\$(__terraform_ps1)${RESET}"
fi

PS1+=' $(__ps1_previous_status)'

__elapsed_ps1() {
  local _START="${1}"

  if [[ ${_START} -gt 0 ]]; then
    local _ELAPSED=$((EPOCHSECONDS - _START))

    if [[ ${_ELAPSED} -gt 0 ]]; then
      printf "⏳%ss" "${_ELAPSED}"
    fi
  fi
}

PS0='${PS1:PS0time=${EPOCHSECONDS}:0}'
PS1+=" \$(__elapsed_ps1 \${PS0time})\${PS0:PS0time=0:0}\n> "
