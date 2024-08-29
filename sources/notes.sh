#!/usr/bin/env bash

notes_erase() {
  if [[ -d ${NOTES_FOLDER:-${HOME}/notes} ]]; then
    rm -rf "${NOTES_FOLDER:-${HOME}/notes}"
  fi
}

notes() {
  local NOTES_ACTION="${1:-}"
  shift || true

  local REAL_NOTES_FOLDER="${NOTES_FOLDER:-${HOME}/notes}"

  case "${NOTES_ACTION}" in
  "open" | "")
    "${NOTES_EDITOR:-${EDITOR}}" "${REAL_NOTES_FOLDER}"
    ;;

  "save")
    (
      cd "${REAL_NOTES_FOLDER}" || return
      git add --all
      git commit --signoff --message "docs: $(date +"%Y-%m-%dT%H:%M:%S%z")"
    )
    ;;

  "sync")
    (
      if ! [[ -d ${REAL_NOTES_FOLDER} ]]; then
        git clone "${NOTES_REPOSITORY:-git@github.com:ViBiOh/notes.git}" "${REAL_NOTES_FOLDER}"
        cd "${REAL_NOTES_FOLDER}" || return
        sublime_add_project
      else
        cd "${REAL_NOTES_FOLDER}" || return
        git pull
        git push
      fi
    )
    ;;

  esac
}

_complete_notes() {
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "open save sync" -- "${COMP_WORDS[COMP_CWORD]}")
    return
  fi
}

[[ -n ${BASH} ]] && complete -F _complete_notes -o default -o bashdefault notes
