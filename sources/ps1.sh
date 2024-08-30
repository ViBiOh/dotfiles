#!/usr/bin/env bash

export GIT_PS1_SHOWDIRTYSTATE="true"
export GIT_PS1_STATESEPARATOR="|"
export GIT_PS1_SHOWSTASHSTATE="true"
export GIT_PS1_SHOWUNTRACKEDFILES="true"
export GIT_PS1_COMPRESSSPARSESTATE="true"

export PROMPT_DIRTRIM="3"

_ps1_previous_status() {
  if [[ ${?} -eq 0 ]]; then
    printf -- "%b✔%b" "${GREEN}" "${RESET}"
  else
    printf -- "%bx%b" "${RED}" "${RESET}"
  fi
}

PS1_PATTERN="${BLUE}\u${RESET}@${RED}\h${RESET} ${GREEN}\w${RESET}"
if [[ "$(type -t "__git_ps1")" == "function" ]]; then
  PS1_PATTERN+="${YELLOW}\$(__git_ps1)${RESET}"
fi

if [[ "$(type -t "__kube_ps1")" == "function" ]]; then
  PS1_PATTERN+="${BLUE}\$(__kube_ps1)${RESET}"
fi

if [[ "$(type -t "__terraform_ps1")" == "function" ]]; then
  PS1_PATTERN+="${PURPLE}\$(__terraform_ps1)${RESET}"
fi

PS1_PATTERN+=' $(_ps1_previous_status)'
PS1_BASH_TIMER="$(mktemp)"

PS0='$(printf "%d" "${SECONDS}" > "${PS1_BASH_TIMER}")'

_update_ps1() {
  local __END="${SECONDS}"
  local __START

  if [[ -e ${PS1_BASH_TIMER:-} ]]; then
    __START=$(cat "${PS1_BASH_TIMER}")
    printf "" >"${PS1_BASH_TIMER}"
  fi

  local DURATION="$((__END - ${__START:-__END}))"

  PS1="${PS1_PATTERN}"
  if [[ ${DURATION} -gt 0 ]]; then
    PS1+=" ⏳${DURATION}s"
  fi

  PS1+="\n> "
}

PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
