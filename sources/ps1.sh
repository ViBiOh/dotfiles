#!/usr/bin/env bash

export PROMPT_DIRTRIM="3"

PS1="${BLUE}\u${RESET}@${RED}\h${RESET} ${GREEN}\w${RESET}"

__git_ps1() {
  # preserve exit status
  local exit="${?}"

  if [[ $(git rev-parse --is-inside-work-tree 2>&1) == "true" ]]; then
    local _GIT_STATUS_PORCELAIN
    _GIT_STATUS_PORCELAIN="$(git status --porcelain --untracked-files=normal)"

    local _GIT_STATUS_BRANCH
    _GIT_STATUS_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

    local _GIT_LOCAL_CHANGE
    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}" | grep --count --extended-regexp "^.[MTADRC]") -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="*"
    fi

    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}" | grep --count --extended-regexp "^[MTADRC]") -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="+"
    fi

    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}" | grep --count --extended-regexp "^[DAU][DAU]") -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="💥"
    fi

    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}" | grep --count "^?") -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="$"
    fi

    if [[ $(git stash list | wc -l) -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="%"
    fi

    if [[ -n ${_GIT_LOCAL_CHANGE} ]]; then
      _GIT_LOCAL_CHANGE="|${_GIT_LOCAL_CHANGE}"
    fi

    printf " (%s%s)" "${_GIT_STATUS_BRANCH}" "${_GIT_LOCAL_CHANGE}"
  fi

  return "${exit}"
}

PS1+="${YELLOW}\$(__git_ps1)${RESET}"

if [[ "$(type -t "__kube_ps1")" == "function" ]]; then
  PS1+="${BLUE}\$(__kube_ps1)${RESET}"
fi

if [[ "$(type -t "__terraform_ps1")" == "function" ]]; then
  PS1+="${PURPLE}\$(__terraform_ps1)${RESET}"
fi

__previous_status_ps1() {
  if [[ ${?} -eq 0 ]]; then
    printf -- "%b✔%b" "${GREEN}" "${RESET}"
  else
    printf -- "%bx%b" "${RED}" "${RESET}"
  fi
}

PS1+=' $(__previous_status_ps1)'

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
