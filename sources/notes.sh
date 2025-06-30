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

  _note_lock() {
    cd "${REAL_NOTES_FOLDER}" || return

    while IFS= read -r file; do
      gpg --yes --encrypt --recipient "${NOTES_AUTHOR:-}" "${file}"
    done < <(rg --files --glob '*.md')
  }

  _notes_unlock() {
    cd "${REAL_NOTES_FOLDER}" || return

    while IFS= read -r file; do
      local TEMP_FILE
      TEMP_FILE="$(mktemp)"

      gpg --yes --quiet --output "${TEMP_FILE}" --decrypt "${file}"
      if [[ $(delta "${file%.gpg}" "${TEMP_FILE}" | wc -l) -gt 0 ]]; then
        smerge mergetool -o "${file%.gpg}" "${file%.gpg}" "${TEMP_FILE}"
      fi

      rm "${TEMP_FILE}"
    done < <(rg --files --glob '*.md.gpg')
  }

  case "${NOTES_ACTION}" in
  "lock")
    _note_lock
    ;;

  "open" | "")
    "${NOTES_EDITOR:-${EDITOR}}" "${REAL_NOTES_FOLDER}"
    ;;

  "save")
    (
      cd "${REAL_NOTES_FOLDER}" || return
      _note_lock
      git add '*.md.gpg'
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
        _notes_unlock
      fi
    )
    ;;

  "unlock")
    _notes_unlock
    ;;

  esac
}

_complete_notes() {
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "lock open save sync unlock" -- "${COMP_WORDS[COMP_CWORD]}")
    return
  fi
}

[[ -n ${BASH} ]] && complete -F _complete_notes -o default -o bashdefault notes
