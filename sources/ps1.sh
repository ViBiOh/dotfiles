#!/usr/bin/env bash

export PROMPT_DIRTRIM="3"

__ps1_previous_status() {
  if [[ ${?} -eq 0 ]]; then
    printf -- "%b✔%b" "${GREEN}" "${RESET}"
  else
    printf -- "%bx%b" "${RED}" "${RESET}"
  fi
}

_git_ps1() {
  # preserve exit status
  local exit="${?}"

  if [[ $(git rev-parse --is-inside-work-tree 2>&1) == "true" ]]; then
    local _GIT_STATUS_PORCELAIN
    _GIT_STATUS_PORCELAIN="$(git status --porcelain --branch --untracked-files=normal)"

    local _GIT_STATUS_BRANCH
    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}") =~ ^##\ ([^.]+).*$ ]]; then
      _GIT_STATUS_BRANCH="${BASH_REMATCH[1]}"
    fi

    local _GIT_LOCAL_CHANGE
    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}" | grep -c "^.M") -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="*"
    fi

    if [[ $(printf "%s" "${_GIT_STATUS_PORCELAIN}" | grep -c "^??") -gt 0 ]]; then
      _GIT_LOCAL_CHANGE+="$"
    fi

    if [[ -n ${_GIT_LOCAL_CHANGE} ]]; then
      _GIT_LOCAL_CHANGE="|${_GIT_LOCAL_CHANGE}"
    fi

    printf " (%s%s)" "${_GIT_STATUS_BRANCH}" "${_GIT_LOCAL_CHANGE}"
  fi

  return "${exit}"
}

PS1="${BLUE}\u${RESET}@${RED}\h${RESET} ${GREEN}\w${RESET}"
if [[ "$(type -t "_git_ps1")" == "function" ]]; then
  PS1+="${YELLOW}\$(_git_ps1)${RESET}"
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
