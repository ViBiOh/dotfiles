#!/usr/bin/env bash

jira() {
  GITHUB_TOKEN="$(github_token)" _jira "${JIRA_DOMAIN}" "Basic $(pass_get "${JIRA_PASS}" "basic")" "${@}"
}

_jira() {
  if [[ ${#} -lt 2 ]]; then
    _jira_help
    return 1
  fi

  local JIRA_DOMAIN="${1}"
  shift

  local JIRA_AUTHORIZATION="${1}"
  shift

  local scope="assignee"

  OPTIND=0

  while getopts ":s:" option; do
    case "${option}" in
    s)
      scope="${OPTARG}"
      ;;

    :)
      printf -- "option -%s requires a value\n" "${OPTARG}" 1>&2
      return 1
      ;;

    \?)
      printf -- "option -%s is invalid\n" "${OPTARG}" 1>&2
      return 2
      ;;
    esac
  done

  shift $((OPTIND - 1))

  local ACTION="${1-}"

  if [[ -z ${ACTION} ]]; then
    _jira_help
    return 1
  fi

  shift

  case ${ACTION} in
  "branch")
    local JIRA_ISSUE
    JIRA_ISSUE="$(_jira_issue "${scope}" "${1-}")"

    if [[ -z ${JIRA_ISSUE} ]]; then
      return
    fi

    _jira_info "Issue ${JIRA_ISSUE}"
    _jira_branch
    ;;

  "create")
    local JIRA_PROJECT
    JIRA_PROJECT="$(_jira_project)"

    if [[ -z ${JIRA_PROJECT} ]]; then
      return
    fi

    JIRA_PROJECT_KEY="$(printf -- "%s" "${JIRA_PROJECT}" | awk '{printf("%s", $2)}')"

    _jira_info "Project: ${JIRA_PROJECT_KEY}"
    JIRA_PROJECT="$(printf -- "%s" "${JIRA_PROJECT}" | awk '{printf("%s", $1)}')"

    local JIRA_ISSUE_TYPE
    JIRA_ISSUE_TYPE="$(_jira_issue_type "${JIRA_PROJECT}")"

    if [[ -z ${JIRA_ISSUE_TYPE} ]]; then
      return
    fi

    _jira_info "Issue Type: $(printf -- "%s" "${JIRA_ISSUE_TYPE}" | cut -f 2- -d ' ')"
    JIRA_ISSUE_TYPE="$(printf -- "%s" "${JIRA_ISSUE_TYPE}" | awk '{printf("%s", $1)}')"

    local JIRA_ISSUE_SUMMARY
    _jira_read_input "Summary: " JIRA_ISSUE_SUMMARY

    local JIRA_USER
    if _jira_confirm "Self assign" "true"; then
      JIRA_USER="$(_jira_self_user)"
      _jira_info "User: ${JIRA_ISSUE_TYPE}"
    fi

    local JIRA_PRIORITY
    JIRA_PRIORITY="$(_jira_priority)"

    _jira_info "Piority: $(printf -- "%s" "${JIRA_PRIORITY}" | cut -f 2- -d ' ')"
    JIRA_PRIORITY="$(printf -- "%s" "${JIRA_PRIORITY}" | awk '{printf("%s", $1)}')"

    local JIRA_CREATE_ISSUE_PAYLOAD
    JIRA_CREATE_ISSUE_PAYLOAD="$(jq --compact-output --null-input \
      --arg project "${JIRA_PROJECT}" \
      --arg user "${JIRA_USER}" \
      --arg issuetype "${JIRA_ISSUE_TYPE}" \
      --arg summary "${JIRA_ISSUE_SUMMARY}" \
      --arg priority "${JIRA_PRIORITY}" \
      '{
        fields: {
          summary: $summary,
          project: {
            id: $project
          },
          issuetype: {
            id: $issuetype
          },
          priority: {
            id: $priority
          }
        }
      }')"

    if [[ -n ${JIRA_USER-} ]]; then
      JIRA_CREATE_ISSUE_PAYLOAD="$(_jira_append_create "$(jq --null-input --arg user "${JIRA_USER}" '{fields: { assignee: {id: $user} } }')")"
    fi

    local JIRA_EPIC
    JIRA_EPIC="$(_jira_epic "${JIRA_PROJECT_KEY}")"

    if [[ ${JIRA_EPIC:-None} != "None" ]]; then
      _jira_info "Epic:$(printf -- "%s" "${JIRA_EPIC}" | awk '{$1=""; print}')"

      JIRA_CREATE_ISSUE_PAYLOAD="$(_jira_append_create "$(jq --null-input --arg epic "$(printf -- "%s" "${JIRA_EPIC}" | awk '{printf("%s", $1)}')" '{fields: { parent: {id: $epic} } }')")"
    fi

    local JIRA_LABELS
    JIRA_LABELS="$(_jira_issue_labels)"

    if [[ -n ${JIRA_LABELS:-} ]] && ! [[ ${JIRA_LABELS:-} =~ "None" ]]; then
      _jira_info "Labels: $(printf -- "%s" "${JIRA_LABELS}" | tr "\n" "," | sed 's|.$||')"

      JIRA_CREATE_ISSUE_PAYLOAD="$(_jira_append_create "$(jq --null-input --argjson labels "$(printf -- "%s" "${JIRA_LABELS}" | jq --raw-input . | jq --slurp .)" '{fields: { labels: $labels } }')")"
    fi

    local EXTRA_FIELDS_NAMES
    EXTRA_FIELDS_NAMES="$(_jira_extra_fields "${JIRA_PROJECT}" "${JIRA_ISSUE_TYPE}")"

    while true; do
      local EXTRA_FIELD_OUTPUT
      EXTRA_FIELD_OUTPUT="$(_jira_fill_extra_fields "${EXTRA_FIELDS_NAMES}")"

      if [[ -z ${EXTRA_FIELD_OUTPUT} ]]; then
        break
      fi

      JIRA_CREATE_ISSUE_PAYLOAD="$(_jira_append_create "${EXTRA_FIELD_OUTPUT}")"
    done

    printf -- "%s" "${JIRA_CREATE_ISSUE_PAYLOAD}" | jq

    if _jira_confirm "Submit"; then
      local JIRA_ISSUE_CREATION
      JIRA_ISSUE_CREATION="$(_jira_request "/rest/api/3/issue" --request "POST" --header "Content-Type: application/json" --data "${JIRA_CREATE_ISSUE_PAYLOAD}")"

      if [[ -n ${JIRA_ISSUE_CREATION} ]]; then
        local JIRA_ISSUE
        JIRA_ISSUE="$(printf -- "%s" "${JIRA_ISSUE_CREATION}" | jq --raw-output '.key')"

        _jira_info "Issue ${JIRA_ISSUE} created"

        if _jira_confirm "Open in browser" "true"; then
          open "${JIRA_DOMAIN}/browse/${JIRA_ISSUE}"
        fi

        if _jira_confirm "Change status" "true"; then
          _jira_transition "${JIRA_ISSUE}"
        fi

        if _jira_confirm "Create branch" "true"; then
          _jira_branch
        fi
      fi
    fi

    ;;

  "pr")
    if [[ $(git rev-parse --is-inside-work-tree 2>&1) != "true" ]]; then
      _jira_error "not in a git directory"
      return 1
    fi

    if [[ -z ${GITHUB_TOKEN:-} ]]; then
      _jira_error "no GITHUB_TOKEN environment varaible found"
      return 1
    fi

    local GITHUB_REPOSITORY
    if [[ "$(git remote get-url --push "$(git remote show | head -1)")" =~ ^.*@.*:([^\.]*)(.git)?$ ]]; then
      GITHUB_REPOSITORY="${BASH_REMATCH[1]}"
    else
      _jira_error "unable to identify git remote repository"
      return 1
    fi

    local GIT_CURRENT_BRANCH
    GIT_CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

    local JIRA_TICKET_ID
    JIRA_TICKET_ID="$(_jira_issue "${scope}" "${GIT_CURRENT_BRANCH}")"

    if [[ -z ${JIRA_TICKET_ID} ]]; then
      return
    fi

    _jira_github_branch "${GITHUB_REPOSITORY}" "${GIT_CURRENT_BRANCH}"
    _jira_github_pull_request "${GITHUB_REPOSITORY}" "${GIT_CURRENT_BRANCH}" "${JIRA_TICKET_ID}"

    if _jira_confirm "Change status" "true"; then
      _jira_transition "${JIRA_TICKET_ID}"
    fi
    ;;

  "print")
    local JIRA_ISSUE
    JIRA_ISSUE="$(_jira_issue "${scope}" "${1-}")"

    if [[ -z ${JIRA_ISSUE} ]]; then
      return
    fi

    printf -- "%s" "${JIRA_ISSUE}"
    ;;

  "summary")
    local JIRA_ISSUE
    JIRA_ISSUE="$(_jira_issue "${scope}" "${1-}")"

    if [[ -z ${JIRA_ISSUE} ]]; then
      return
    fi

    _jira_summary "${JIRA_ISSUE}"
    ;;

  "transition")
    local JIRA_ISSUE
    JIRA_ISSUE="$(_jira_issue "${scope}" "${1-}")"

    if [[ -z ${JIRA_ISSUE} ]]; then
      return
    fi

    _jira_transition "${JIRA_ISSUE}" "${2-}"
    ;;

  "url")
    local JIRA_ISSUE
    JIRA_ISSUE="$(_jira_issue "${scope}" "${1-}")"

    if [[ -z ${JIRA_ISSUE} ]]; then
      return
    fi

    _jira_url "${JIRA_ISSUE}"
    ;;

  *)
    _jira_help
    return 1
    ;;
  esac
}

_jira_append_create() {
  printf -- "%s %s" "${JIRA_CREATE_ISSUE_PAYLOAD}" "${1}" | jq --compact-output --slurp '.[0] * .[1]'
}

_jira_branch() {
  if [[ $(git rev-parse --is-inside-work-tree 2>&1) != "true" ]]; then
    _jira_error "not in a git directory"
  fi

  local JIRA_BRANCH_NAME="${JIRA_ISSUE}"

  local BRANCH_PREFIX
  _jira_read "BRANCH_PREFIX" "${JIRA_BRANCH_PREFIX:-}"
  if [[ -n ${BRANCH_PREFIX} ]]; then
    JIRA_BRANCH_NAME="${BRANCH_PREFIX}${JIRA_BRANCH_NAME}"
  fi

  local BRANCH_SUFFIX
  _jira_read "BRANCH_SUFFIX" "${JIRA_BRANCH_SUFFIX:-}"
  if [[ -n ${BRANCH_SUFFIX} ]]; then
    JIRA_BRANCH_NAME="${JIRA_BRANCH_NAME}${BRANCH_SUFFIX}"
  fi

  local CHECKOUT_OPTION=""
  if ! git rev-parse --quiet --verify "${JIRA_BRANCH_NAME}" >/dev/null 2>&1; then
    CHECKOUT_OPTION+=" -b"
  fi

  eval "git checkout ${CHECKOUT_OPTION} ${JIRA_BRANCH_NAME}"
}

_jira_transition() {
  local JIRA_ISSUE="${1}"
  shift

  local JIRA_TRANSITIONS
  JIRA_TRANSITIONS="$(_jira_request "/rest/api/3/issue/${JIRA_ISSUE}/transitions" --get --data-urlencode "expand=transitions.fields")"

  if [[ -z ${JIRA_TRANSITIONS} ]]; then
    return
  fi

  local JIRA_TRANSITION
  JIRA_TRANSITION="$(
    printf -- "%s" "${JIRA_TRANSITIONS}" | jq --raw-output '.transitions[] | .id + " " + .name' |
      fzf --exit-0 --prompt="Status: " --select-1 --query "${2-}"
  )"

  if [[ -z ${JIRA_TRANSITION} ]]; then
    return
  fi

  local JIRA_TRANSITION_ID
  JIRA_TRANSITION_ID="$(printf -- "%s" "${JIRA_TRANSITION}" | awk '{printf("%s", $1)}')"

  local JIRA_TRANSITION_NAME
  JIRA_TRANSITION_NAME="$(printf -- "%s" "${JIRA_TRANSITION}" | awk '{$1=""; print}')"

  local JIRA_TRANSITION_PAYLOAD
  JIRA_TRANSITION_PAYLOAD="$(jq --null-input --compact-output --arg transition_id "${JIRA_TRANSITION_ID}" '{transition: $transition_id}')"

  local JIRA_TRANSITION_FIELDS
  JIRA_TRANSITION_FIELDS="$(printf -- "%s" "${JIRA_TRANSITIONS}" | jq --arg transitionID "${JIRA_TRANSITION_ID}" '.transitions[] | select(.id == $transitionID) | .fields[]')"

  while true; do
    local EXTRA_FIELD_OUTPUT
    EXTRA_FIELD_OUTPUT="$(_jira_fill_extra_fields "${JIRA_TRANSITION_FIELDS}")"

    if [[ -z ${EXTRA_FIELD_OUTPUT} ]]; then
      break
    fi

    JIRA_TRANSITION_PAYLOAD="$(printf -- "%s %s" "${JIRA_TRANSITION_PAYLOAD}" "${EXTRA_FIELD_OUTPUT}" | jq --compact-output --slurp '.[0] * .[1]')"
  done

  _jira_request "/rest/api/3/issue/${JIRA_ISSUE}/transitions" --request "POST" --header "Content-Type: application/json" --data "${JIRA_TRANSITION_PAYLOAD}"
  _jira_info "${JIRA_ISSUE} transitionned to status${JIRA_TRANSITION_NAME}"
}

_jira_info() {
  printf -- "%b%b %b\n" "${BLUE}" "${*}" "${RESET}" 1>&2
}

_jira_warning() {
  printf -- "%b%b %b\n" "${YELLOW}" "${*}" "${RESET}" 1>&2
}

_jira_error() {
  printf -- "%b%b %b\n" "${RED}" "${*}" "${RESET}" 1>&2
}

_jira_read() {
  local VAR_NAME="${1}"
  shift
  local VAR_DEFAULT="${1-}"
  shift || true

  local VAR_DEFAULT_DISPLAY=""
  if [[ -n ${VAR_DEFAULT} ]]; then
    VAR_DEFAULT_DISPLAY=" [${VAR_DEFAULT}]"
  fi

  _jira_read_input "${VAR_NAME}${VAR_DEFAULT_DISPLAY}=" "READ_VALUE"

  local VAR_SAFE_VALUE
  VAR_SAFE_VALUE="$(printf -- "%s" "${READ_VALUE:-${VAR_DEFAULT}}" | sed "s|'|\\\'|g")"
  eval "${VAR_NAME}=$'${VAR_SAFE_VALUE}'"
}

_jira_read_input() {
  local VAR_PROMPT="${1}"
  shift

  local VAR_NAME="${1}"
  shift

  if [[ -n ${BASH_VERSION} ]]; then
    read -r -p "${VAR_PROMPT}" "${VAR_NAME}" </dev/tty
  elif [[ -n ${ZSH_VERSION} ]]; then
    read -r "${VAR_NAME}?${VAR_PROMPT}" </dev/tty
  else
    return 1
  fi
}

_jira_confirm() {
  local DEFAULT_PROMPT="[y/N]"
  local DEFAULT_RETURN=1

  if [[ ${2:-} == "true" ]] || [[ ${2:-} == "0" ]]; then
    DEFAULT_RETURN=0
    DEFAULT_PROMPT="[Y/n]"
  fi

  local input
  _jira_read_input "${1:-Are you sure}? ${DEFAULT_PROMPT} " input

  case "${input}" in
  [yY][eE][sS] | [yY])
    return 0
    ;;

  [nN][oO] | [nN])
    return 1
    ;;

  *)
    return ${DEFAULT_RETURN}
    ;;
  esac
}

_jira_help() {
  _jira_error "Usage: jira JIRA_DOMAIN JIRA_AUTHORIZATION [options?] ACTION"

  _jira_warning "\n"
  _jira_warning "\tJIRA_DOMAIN         like  https://my.atlassian.net"
  _jira_warning "\tJIRA_AUTHORIZATION  like  Basic YWRtaW46cGFzc3dvcmQ= (i.e. printf 'admin:password' | base64)"

  _jira_info "\nPossibles options are\n"
  _jira_info " - -s Scope of tickets searched"
  _jira_info "   \t- 'assignee': only tickets on which current user is assignee (default value)"
  _jira_info "   \t- 'reporter': only tickets on which current user is reporter"
  _jira_info "   \t- 'all': no filter"

  _jira_info "\nPossibles actions are                                  | args\n"
  _jira_info " - branch      Switch git repository branch to ticket  | <search text>?"
  _jira_info " - create      Create a ticket interactively           |"
  _jira_info " - pr          Open pull-request for current branch"
  _jira_info " - print       Print ticket ID                         | <search text>?"
  _jira_info " - summary     Print the summary of a ticket           | <search text>?"
  _jira_info " - transition  Transition ticket to another state      | <search text>?"
  _jira_info " - url         Print URL for ticket                    | <search text>?"
}

_jira_github_branch() {
  local GITHUB_REPOSITORY="${1}"
  local GIT_CURRENT_BRANCH="${2}"

  local GITHUB_PRINT_OUTPUT="false"
  local GITHUB_PRINT_ERROR="false"

  if ! _jira_github_request "/repos/${GITHUB_REPOSITORY}/branches/${GIT_CURRENT_BRANCH}"; then
    _jira_warning "Remote branch '${GIT_CURRENT_BRANCH}' doesn't exist."

    if _jira_confirm "Run 'git push'"; then
      git push
    fi
  fi
}

_jira_github_pull_request() {
  local GITHUB_REPOSITORY="${1}"
  local GIT_CURRENT_BRANCH="${2}"
  local JIRA_TICKET_ID="${3}"

  local PULL_REQUEST_BODY
  PULL_REQUEST_BODY="[${JIRA_TICKET_ID}]($(_jira_url "${JIRA_TICKET_ID}"))"

  local GITHUB_PR_TEMPLATE
  GITHUB_PR_TEMPLATE="$(git rev-parse --show-toplevel)/.github/PULL_REQUEST_TEMPLATE.md"
  if [[ -e ${GITHUB_PR_TEMPLATE} ]]; then
    PULL_REQUEST_BODY+=$'\n\n'
    PULL_REQUEST_BODY+="$(cat "${GITHUB_PR_TEMPLATE}")"
  fi

  local GITHUB_PRINT_OUTPUT="true"
  local GITHUB_PRINT_ERROR="true"

  local GITHUB_OUTPUT
  GITHUB_OUTPUT="$(_jira_github_request "/repos/${GITHUB_REPOSITORY}/pulls" \
    --data "$(
      jq --compact-output --null-input \
        --arg title "$(_jira_summary "${JIRA_TICKET_ID}")" \
        --arg base "$(git remote show origin | grep 'HEAD branch:' | awk '{printf("%s", $3)}')" \
        --arg head "${GIT_CURRENT_BRANCH}" \
        --arg body "${PULL_REQUEST_BODY}" \
        '{title: $title, base: $base, head: $head, body: $body, draft: true}'
    )")"

  if [[ -n ${GITHUB_OUTPUT} ]]; then
    open "$(printf -- "%s" "${GITHUB_OUTPUT}" | jq --raw-output '.html_url')"
  fi
}

_jira_github_request() {
  if [[ ${#} -lt 1 ]]; then
    _jira_error "Usage: _github_request PATH [EXTRA_CURL_ARGS]"
    return 1
  fi

  local HEADER_OUTPUT
  HEADER_OUTPUT=$(mktemp)

  local URL
  URL="https://api.github.com${1-}"
  shift 1

  local GITHUB_OUTPUT
  GITHUB_OUTPUT="$(
    curl \
      --disable \
      --silent \
      --show-error \
      --location \
      --max-time 10 \
      --dump-header "${HEADER_OUTPUT}" \
      --fail-with-body \
      --header "Accept: application/vnd.github+json" \
      --header "Authorization: Bearer ${GITHUB_TOKEN}" \
      "${URL}" \
      "${@}"
  )"

  if [[ ${?} -ne 0 ]]; then
    if [[ ${GITHUB_PRINT_ERROR:-} == "true" ]]; then
      cat "${HEADER_OUTPUT}" >/dev/stderr
      printf -- "%s\n" "${GITHUB_OUTPUT}" >/dev/stderr
    fi

    rm -f "${HEADER_OUTPUT}"
    return 1
  fi

  rm -f "${HEADER_OUTPUT}"

  if [[ ${GITHUB_PRINT_OUTPUT:-} == "true" ]]; then
    printf -- "%s" "${GITHUB_OUTPUT}"
  fi
}

_jira_request() {
  if [[ ${#} -lt 1 ]]; then
    _jira_error "Usage: _jira_request PATH [EXTRA_CURL_ARGS]"
    return 1
  fi

  local HEADER_OUTPUT
  HEADER_OUTPUT=$(mktemp)

  local URL
  URL="${JIRA_DOMAIN}${1-}"
  shift 1

  local JIRA_OUTPUT
  JIRA_OUTPUT="$(
    curl \
      --disable \
      --silent \
      --show-error \
      --location \
      --max-time 10 \
      --dump-header "${HEADER_OUTPUT}" \
      --fail-with-body \
      --header "Accept: application/json" \
      --header "Authorization: ${JIRA_AUTHORIZATION}" \
      "${URL}" \
      "${@}"
  )"

  if [[ ${?} -ne 0 ]]; then
    cat "${HEADER_OUTPUT}" >/dev/stderr
    printf -- "%s\n" "${JIRA_OUTPUT}" >/dev/stderr
    rm -f "${HEADER_OUTPUT}"
    return 1
  fi

  rm -f "${HEADER_OUTPUT}"
  printf -- "%s" "${JIRA_OUTPUT}"
}

_jira_issue() {
  local JIRA_JQL="status NOT IN (Done, Closed, Resolved)"

  if [[ ${1-} == "assignee" ]]; then
    JIRA_JQL+=" AND assignee = currentUser()"
  elif [[ ${1-} == "reporter" ]]; then
    JIRA_JQL+=" AND reporter = currentUser()"
  fi

  if [[ -n ${2-} ]]; then
    if [[ ${2} =~ ([A-Z0-9]+[-_][0-9]+) ]]; then
      JIRA_JQL+=" AND id = '${BASH_REMATCH[1]}'"
    else
      JIRA_JQL+=" AND text ~ \"${2}\""
    fi
  fi

  JIRA_JQL+=" ORDER BY updated DESC"

  local JIRA_OUTPUT
  JIRA_OUTPUT="$(_jira_request "/rest/api/3/search" --get --data-urlencode "maxResults=200" --data-urlencode "jql=${JIRA_JQL}")"

  if [[ -z ${JIRA_OUTPUT} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_OUTPUT}" | jq --raw-output '.issues[] | .key + " " + .fields.summary' |
    fzf --exit-0 --prompt="Issue: " --select-1 |
    awk '{printf("%s", $1)}'
}

_jira_epic() {
  local JIRA_PROJECT_NAME="${1-}"

  local JIRA_JQL="issuetype = Epic and status NOT IN (Done, Closed, Resolved) and project = ${JIRA_PROJECT_NAME}"
  JIRA_JQL+=" ORDER BY updated DESC"

  local JIRA_OUTPUT
  JIRA_OUTPUT="$(_jira_request "/rest/api/3/search" --get --data-urlencode "maxResults=50" --data-urlencode "jql=${JIRA_JQL}")"

  if [[ -z ${JIRA_OUTPUT} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_OUTPUT}" | jq --raw-output '.issues[] | .id + " " + .fields.summary' | awk 'BEGIN{print "None"}1' |
    fzf --exit-0 --prompt="Epic: "
}

_jira_project() {
  local JIRA_PROJECTS
  JIRA_PROJECTS="$(_jira_request "/rest/api/3/project/recent" --get)"

  if [[ -z ${JIRA_PROJECTS} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_PROJECTS}" | jq --raw-output '.[] | .id + " " + .key + " " + .name' |
    fzf --exit-0 --prompt="Project: "
}

_jira_summary() {
  local JIRA_ISSUE_PAYLOAD
  JIRA_ISSUE_PAYLOAD="$(_jira_request "/rest/api/latest/issue/${1-}" --get)"

  if [[ -z ${JIRA_ISSUE_PAYLOAD} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_ISSUE_PAYLOAD}" | jq --raw-output '.key + " " + .fields.summary'
}

_jira_issue_type() {
  local JIRA_PROJECT="${1}"
  shift

  local JIRA_ISSUE_TYPES
  JIRA_ISSUE_TYPES="$(_jira_request "/rest/api/3/issuetype/project" --get --data-urlencode "projectId=${JIRA_PROJECT}" --data-urlencode "level=0")"

  if [[ -z ${JIRA_ISSUE_TYPES} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_ISSUE_TYPES}" | jq --raw-output '.[] | .id + " " + .name' |
    fzf --exit-0 --prompt="Issue Type: "
}

_jira_priority() {
  local JIRA_PRIORITY
  JIRA_PRIORITY="$(_jira_request "/rest/api/3/priority" --get)"

  if [[ -z ${JIRA_PRIORITY} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_PRIORITY}" | jq --raw-output '.[] | .id + " " + .name' |
    fzf --exit-0 --prompt="Priority: "
}

_jira_issue_labels() {
  local READ_LABELS=0

  while
    printf -- "None\n"

    local JIRA_LABEL_PAYLOAD
    JIRA_LABEL_PAYLOAD="$(_jira_request "/rest/api/3/label" --get --data-urlencode "startAt=${READ_LABELS}")"

    if [[ -z ${JIRA_LABEL_PAYLOAD} ]]; then
      break
    fi

    for label in $(printf -- "%s" "${JIRA_LABEL_PAYLOAD}" | jq --raw-output '.values[]'); do
      if [[ ${label} =~ [a-zA-Z0-9_-]{2,} ]]; then
        printf -- "%s\n" "${label}"
      fi

      READ_LABELS=$((READ_LABELS + 1))
    done

    if [[ $(printf -- "%s" "${JIRA_LABEL_PAYLOAD}" | jq --raw-output '.isLast') == "true" ]]; then
      break
    fi
  do true; done | fzf --exit-0 --multi --prompt="Labels (multi-select with Tab): "
}

_jira_extra_fields() {
  local JIRA_PROJECT="${1}"
  shift

  local JIRA_ISSUE_TYPE="${1}"
  shift

  local JIRA_EXTRA_FIELDS
  JIRA_EXTRA_FIELDS="$(_jira_request "/rest/api/3/issue/createmeta" --get --data-urlencode "projectIds=${JIRA_PROJECT}" --data-urlencode "issuetypeIds=${JIRA_ISSUE_TYPE}" --data-urlencode "expand=projects.issuetypes.fields")"

  if [[ -z ${JIRA_EXTRA_FIELDS} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_EXTRA_FIELDS}" | jq --raw-output '.projects[].issuetypes[].fields[] | select(.key | startswith("customfield")) | select(.schema.type == "number" or .schema.type == "string" or .schema.type == "date" or .schema.type == "option")'
}

_jira_fill_extra_fields() {
  local JIRA_EXTRA_FIELDS="${1}"
  shift

  if [[ -z ${JIRA_EXTRA_FIELDS} ]]; then
    return
  fi

  local EXTRA_FIELD
  EXTRA_FIELD="$(printf '%s' "${JIRA_EXTRA_FIELDS}" | jq --raw-output '.name' | awk 'BEGIN{print "None"}1' | fzf --exit-0 --prompt="Extra field: ")"

  if [[ ${EXTRA_FIELD:-None} == "None" ]]; then
    return
  fi

  local EXTRA_FIELD_TYPE
  EXTRA_FIELD_TYPE="$(printf -- "%s" "${JIRA_EXTRA_FIELDS}" | jq --arg name "${EXTRA_FIELD}" --raw-output 'select(.name == $name) | .schema.type')"

  local EXTRA_FIELD_VALUE

  case "${EXTRA_FIELD_TYPE}" in
  "option")
    EXTRA_FIELD_VALUE="$(printf -- "%s" "${JIRA_EXTRA_FIELDS}" | jq --arg name "${EXTRA_FIELD}" --raw-output 'select(.name == $name) | .allowedValues[] | .value' | fzf --exit-0 --prompt="${EXTRA_FIELD}: ")"
    ;;

  "resolution" | "array")
    EXTRA_FIELD_VALUE="$(printf -- "%s" "${JIRA_EXTRA_FIELDS}" | jq --arg name "${EXTRA_FIELD}" --raw-output 'select(.name == $name) | .allowedValues[] | .name' | fzf --exit-0 --prompt="${EXTRA_FIELD}: ")"
    ;;

  "date")
    _jira_read_input "${EXTRA_FIELD} (in ISO format YYYY-MM-DD)=" EXTRA_FIELD_VALUE
    ;;

  "string" | "number")
    _jira_read_input "${EXTRA_FIELD}: " EXTRA_FIELD_VALUE
    ;;
  esac

  local EXTRA_FIELD_KEY
  EXTRA_FIELD_KEY="$(printf -- "%s" "${JIRA_EXTRA_FIELDS}" | jq --arg name "${EXTRA_FIELD}" --raw-output 'select(.name == $name) | .key')"

  case "${EXTRA_FIELD_TYPE}" in
  "string" | "date")
    jq --compact-output --null-input --arg key "${EXTRA_FIELD_KEY}" --argjson value "\"${EXTRA_FIELD_VALUE}\"" '{ fields: { ($key): $value } }'
    ;;

  "option")
    jq --compact-output --null-input --arg key "${EXTRA_FIELD_KEY}" --argjson value "\"${EXTRA_FIELD_VALUE}\"" '{ fields: { ($key): {value: $value} } }'
    ;;

  "resolution" | "array")
    jq --compact-output --null-input --arg key "${EXTRA_FIELD_KEY}" --argjson value "\"${EXTRA_FIELD_VALUE}\"" '{ fields: { ($key): {name: $value} } }'
    ;;

  "number")
    jq --compact-output --null-input --arg key "${EXTRA_FIELD_KEY}" --argjson value "${EXTRA_FIELD_VALUE}" '{ fields: { ($key): $value } }'
    ;;
  esac
}

_jira_self_user() {
  local JIRA_USER
  JIRA_USER="$(_jira_request "/rest/api/3/myself" --get)"

  if [[ -z ${JIRA_USER} ]]; then
    return
  fi

  printf -- "%s" "${JIRA_USER}" | jq --raw-output '.accountId'
}

_jira_url() {
  printf -- "%s/browse/%s" "${JIRA_DOMAIN}" "${1}"
}
