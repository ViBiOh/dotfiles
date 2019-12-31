#!/usr/bin/env bash

PS1="${BLUE}\u${RESET}@${RED}\h${RESET} ${GREEN}\w${RESET}"

export GIT_PS1_SHOWDIRTYSTATE="true"
export GIT_PS1_STATESEPARATOR="|"
export GIT_PS1_SHOWSTASHSTATE="true"
export GIT_PS1_SHOWUNTRACKEDFILES="true"

if command -v git > /dev/null 2>&1 && [[ "$(type -t __git_ps1)" = "function" ]]; then
  PS1="${PS1}${YELLOW}\$(__git_ps1)${RESET}"
fi

PROMPT_DIRTRIM="3"

_previous_status() {
  if [[ $? -eq 0 ]]; then
    printf -- "%b✔%b" "${GREEN}" "${RESET}"
  else
    printf -- "%bx%b" "${RED}" "${RESET}"
  fi
}

export PS1="${PS1} \$(_previous_status)\n> "
