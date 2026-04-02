#!/usr/bin/env bash

if ! command -v pass >/dev/null 2>&1 || ! command -v fzf >/dev/null 2>&1; then
  return
fi

pass_get() {
  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: passget PASS_NAME PASS_FIELD"
    return 1
  fi

  local PASS_NAME="${1}"
  shift

  local PASS_FIELD="${1}"
  shift

  if command -v op >/dev/null 2>&1 && [[ ${PASS_NAME} =~ ^[^\/]*$ ]] && op item get --vault Private "${PASS_NAME}" --field "${PASS_FIELD}" >/dev/null 2>&1; then
    op item get --vault Private "${PASS_NAME}" --field "${PASS_FIELD}" --reveal

    return
  fi

  if command -v pass >/dev/null 2>&1 && [[ -e "${PASSWORD_STORE_DIR:-${HOME}/.password-store}/${PASS_NAME}.gpg" ]]; then
    if [[ ${PASS_FIELD} == "password" ]]; then
      pass show "${PASS_NAME}" | awk 'NR==1 {printf("%s", $1)}'
    else
      pass show "${PASS_NAME}" | awk -v "field=${PASS_FIELD}" -F': ' '$1 == field {printf("%s", $2)}'
    fi

    return
  fi

  var_red "No password manager found"
  return 1
}

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
    printf -- "\n"

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
  printf -- "Copied login of %s to clipboard\n" "${PASS_NAME}"
  read -s -r -p "Press enter for password"
  printf -- "\n"

  passfor "${PASS_NAME}"
}

[[ -n ${BASH} ]] && complete -F _fzf_complete_pass -o default -o bashdefault passfull

passweb() {
  if [[ ${#} -ne 1 ]]; then
    var_red "Usage: passweb PASS_NAME"
    return 1
  fi

  local PASS_NAME="${1}"
  shift

  local PASS_URL
  PASS_URL="$(pass_get "${PASS_NAME}" "url")"

  if [[ -z ${PASS_URL} ]]; then
    var_red "no url in the store"
    return 1
  fi

  local PASS_URL_BASIC
  PASS_URL_BASIC="$(pass_get "${PASS_NAME}" "url_basic")"

  if [[ ${PASS_URL_BASIC:-} == "on" ]]; then
    PASS_URL="${PASS_URL/#https:\/\//https:\/\/"$(urlencode "$(pass_get "${PASS_NAME}" "login")")":"$(urlencode "$(pass_get "${PASS_NAME}" "password")")"@}"
    open --url "${PASS_URL}" -a firefox
  else
    open --url "${PASS_URL}"
    passfull "${PASS_NAME}"
  fi
}

[[ -n ${BASH} ]] && complete -F _fzf_complete_pass -o default -o bashdefault passweb

pass_wifi_qrcode() {
  if [[ ${#} -lt 1 ]]; then
    var_red "Usage: pass_wifi_qrcode WIFI_NAME"
    return 1
  fi

  local WIFI_NAME
  WIFI_NAME="${1}"

  local WIFI_PASSWORD
  WIFI_PASSWORD="$(pass_get "wifi/${WIFI_NAME}" "password")"

  if [[ -z ${WIFI_PASSWORD:-} ]]; then
    return
  fi

  qrcode_wifi "${WIFI_NAME}" "${WIFI_PASSWORD}"
}
