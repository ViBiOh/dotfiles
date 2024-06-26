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

PS1+=" \$(_ps1_previous_status)\n> "

export PS1
