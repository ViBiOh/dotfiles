#!/usr/bin/env bash

export PROMPT_DIRTRIM="3"

PS1=""

# Show username and hostname if SSH
if [[ -n ${SSH_CONNECTION:-} ]]; then
  PS1+="${BLUE}\u${RESET}@${RED}\h${RESET} "
fi

# Show red star if root
if [[ $UID -eq 0 ]]; then
  PS1+="${RED}👻${RESET} "
fi

PS1="${GREEN}\w${RESET}"

__git_ps1() {
  # preserve exit status
  local exit="${?}"

  if [[ $(git rev-parse --is-inside-work-tree 2>&1) == "true" ]]; then
    local _GIT_STATUS_PORCELAIN

    local _GIT_STATUS_BRANCH
    local _GIT_LOCAL_CHANGE=0

    while read -r line; do
      if [[ ${line} =~ ^#\ branch\.head\ (.*) ]]; then
        _GIT_STATUS_BRANCH="${BASH_REMATCH[1]}"
      fi

      if [[ ${line} =~ ^[1|2]\ \.[MTADRC] ]]; then
        _GIT_LOCAL_CHANGE=$((_GIT_LOCAL_CHANGE | 1))
      fi

      if [[ ${line} =~ ^[1|2]\ [MTADRC] ]]; then
        _GIT_LOCAL_CHANGE=$((_GIT_LOCAL_CHANGE | 2))
      fi

      if [[ ${line} =~ ^u ]]; then
        _GIT_LOCAL_CHANGE=$((_GIT_LOCAL_CHANGE | 4))
      fi

      if [[ ${line} =~ ^\? ]]; then
        _GIT_LOCAL_CHANGE=$((_GIT_LOCAL_CHANGE | 8))
      fi

      if [[ ${line} =~ ^#\ stash ]]; then
        _GIT_LOCAL_CHANGE=$((_GIT_LOCAL_CHANGE | 16))
      fi
    done <<<"$(git status --porcelain=v2 --branch --show-stash --untracked-files=normal)"

    local _GIT_STATUS_FILES=""

    if [[ $((_GIT_LOCAL_CHANGE & 1)) -ne 0 ]]; then
      _GIT_STATUS_FILES+="*"
    fi

    if [[ $((_GIT_LOCAL_CHANGE & 2)) -ne 0 ]]; then
      _GIT_STATUS_FILES+="+"
    fi

    if [[ $((_GIT_LOCAL_CHANGE & 4)) -ne 0 ]]; then
      _GIT_STATUS_FILES+="💥"
    fi

    if [[ $((_GIT_LOCAL_CHANGE & 8)) -ne 0 ]]; then
      _GIT_STATUS_FILES+="$"
    fi

    if [[ $((_GIT_LOCAL_CHANGE & 16)) -ne 0 ]]; then
      _GIT_STATUS_FILES+="%"
    fi

    if [[ -n ${_GIT_STATUS_FILES} ]]; then
      _GIT_STATUS_FILES="|${_GIT_STATUS_FILES}"
    fi

    printf " (%s%s)" "${_GIT_STATUS_BRANCH}" "${_GIT_STATUS_FILES}"
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
