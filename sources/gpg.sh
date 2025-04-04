#!/usr/bin/env bash

GPG_TTY="$(tty)"
export GPG_TTY

if [[ -z ${SSH_AUTH_SOCK:-} ]]; then
  SSH_AUTH_SOCK="$(gpgconf --list-dirs "agent-ssh-socket")"
  export SSH_AUTH_SOCK
fi

gpg_agent_start() {
  if [[ $(pgrep gpg-agent | wc -l) -eq 1 ]]; then
    return 0
  fi

  gpgconf --launch gpg-agent
  gpg-connect-agent updatestartuptty /bye >/dev/null
}

gpg_agent_stop() {
  gpgconf --kill gpg-agent
}

gpg_eject_card() {
  gpg-connect-agent "scd serialno" "learn --force" /bye
}

if [[ -d ${HOME}/.gnupg ]]; then
  gpg_agent_start
fi

cipher() {
  gpg --symmetric --cipher-algo AES256 "${@}" | base64
}

decipher() {
  base64 -D | gpg --decrypt "${@}"
}

cipher_for() {
  if [[ ${#} -lt 1 ]]; then
    printf -- "%bUsage: cipher_for GITHUB_USERNAME%b\n" "${RED}" "${RESET}" 1>&2
    return 1
  fi

  local GITHUB_USERNAME="${1}"
  shift 1

  local TEMP_GNUPGHOME
  TEMP_GNUPGHOME="$(mktemp -d)"

  cp "${GNUPGHOME:-${HOME}/.gnupg/gpg.conf}" "${TEMP_GNUPGHOME}/gpg.conf"

  local PUBLIC_KEY
  PUBLIC_KEY="$(mktemp)"

  curl --disable --silent --show-error --location --max-time 10 "https://github.com/${GITHUB_USERNAME}.gpg" >"${PUBLIC_KEY}"
  gpg --homedir "${TEMP_GNUPGHOME}" --import "${PUBLIC_KEY}"

  local ENCRYPT_KEY_IDS
  ENCRYPT_KEY_IDS="$(gpg --homedir "${TEMP_GNUPGHOME}" --list-keys --with-colons | grep pub | awk -F: '{print "{\"id\":\"" $5 "\",\"cap\":\"" $12 "\"}"}' | jq --raw-output 'select(.cap | test("e|E")) | .id')"

  if [[ -z ${ENCRYPT_KEY_IDS} ]]; then
    printf -- "%bno encryption key found%b\n" "${RED}" "${RESET}" 1>&2
  else
    local EMAILS

    for keyID in ${ENCRYPT_KEY_IDS}; do
      EMAILS+="$(gpg --homedir "${TEMP_GNUPGHOME}" --list-keys --with-colons "${keyID}" | grep uid | awk -F: '{print $10}')"
      EMAILS+=$'\n'
    done

    local RECIPIENT
    RECIPIENT="$(printf -- "%s" "${EMAILS}" | uniq | fzf --prompt "Email: ")"

    gpg --homedir "${TEMP_GNUPGHOME}" --encrypt --recipient "${RECIPIENT}" "${@}" | base64

    printf -- "%bDecipher with: base64 -D | gpg --decrypt%b\n" "${YELLOW}" "${RESET}" 1>&2
  fi

  rm -rf "${TEMP_GNUPGHOME}" "${PUBLIC_KEY}"
}

_fzf_complete_cipher_for() {
  FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
    local HTTP_OUTPUT
    HTTP_OUTPUT="$(mktemp)"

    local GITHUB_TOKEN
    GITHUB_TOKEN="$(github_token)"

    local HTTP_CLIENT_ARGS=("curl" "--disable" "--silent" "--show-error" "--location" "--max-time" "10" "--output" "${HTTP_OUTPUT}" "--write-out" "%{http_code}" "--header" "Authorization: token ${GITHUB_TOKEN}")
    local HTTP_STATUS

    local FOLLOWERS
    local FOLLOWING
    local MEMBERS

    HTTP_STATUS="$("${HTTP_CLIENT_ARGS[@]}" --header "Accept: application/vnd.github+json" "https://api.github.com/user/followers")"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      printf -- "%bHTTP/%s: Unable to get followers%b\n" "${RED}" "${HTTP_STATUS}" "${RESET}" 1>&2
      return
    fi

    FOLLOWERS="$(jq --raw-output '.[].login' "${HTTP_OUTPUT}")"

    HTTP_STATUS="$("${HTTP_CLIENT_ARGS[@]}" --header "Accept: application/vnd.github+json" "https://api.github.com/user/following")"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      printf -- "%bHTTP/%s: Unable to get following%b\n" "${RED}" "${HTTP_STATUS}" "${RESET}" 1>&2
      cat "${HTTP_OUTPUT}" 1>&2 && rm "${HTTP_OUTPUT}"
      return
    fi

    FOLLOWING="$(jq --raw-output '.[].login' "${HTTP_OUTPUT}")"

    HTTP_STATUS="$("${HTTP_CLIENT_ARGS[@]}" --header "Accept: application/vnd.github+json" "https://api.github.com/user/memberships/orgs")"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      printf -- "%bHTTP/%s: Unable to list orgs%b\n" "${RED}" "${HTTP_STATUS}" "${RESET}" 1>&2
      cat "${HTTP_OUTPUT}" 1>&2 && rm "${HTTP_OUTPUT}"
      return
    fi

    for org in $(jq --raw-output '.[].organization.login' "${HTTP_OUTPUT}"); do
      local page=0
      local page_size=100
      local count="${page_size}"

      while [[ count -eq ${page_size} ]]; do
        page=$((page + 1))

        HTTP_STATUS="$("${HTTP_CLIENT_ARGS[@]}" --header "Accept: application/vnd.github+json" "https://api.github.com/orgs/${org}/members?per_page=${page_size}&page=${page}")"
        if [[ ${HTTP_STATUS} != "200" ]]; then
          printf -- "%bHTTP/%s: Unable to get members of org %s%b\n" "${RED}" "${HTTP_STATUS}" "${org}" "${RESET}" 1>&2
          cat "${HTTP_OUTPUT}" 1>&2 && rm "${HTTP_OUTPUT}"
          return
        fi

        count="$(jq --raw-output 'length' "${HTTP_OUTPUT}")"
        MEMBERS+="$(jq --raw-output '.[].login' "${HTTP_OUTPUT}")"
      done
    done

    rm "${HTTP_OUTPUT}"

    printf -- "%s\n%s\n%s" "${FOLLOWERS}" "${FOLLOWING}" "${MEMBERS}" | sort --unique
  )
}

[[ -n ${BASH} ]] && complete -F _fzf_complete_cipher_for -o default -o bashdefault cipher_for
