#!/usr/bin/env bash

github_token() {
  pass_get "dev/github" "token"
}

github_http_init() {
  meta_check "var" "http"

  http_init_client --header "Authorization: Bearer $(github_token)" --header "Accept: application/vnd.github+json" --header "X-GitHub-Api-Version: 2022-11-28"
}

github() {
  github_http_init

  local GITHUB_API_PATH="${1-}"
  shift || true

  http_request "https://api.github.com${GITHUB_API_PATH}" "${@}"

  if ! [[ ${HTTP_STATUS} =~ 2.. ]]; then
    http_handle_error
    http_reset
    return 1
  fi

  jq --raw-output "." "${HTTP_OUTPUT}"

  http_reset
}

github_rate_limit_wait() {
  local WANTED_CALLS="${1:-10}"
  shift || true

  github_http_init

  while true; do
    http_request "https://api.github.com/rate_limit"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to get rate limit"
      return
    fi

    remaining="$(jq --raw-output '.resources.core.remaining' "${HTTP_OUTPUT}")"
    rm "${HTTP_OUTPUT}"
    if [[ ${remaining} -gt ${WANTED_CALLS} ]]; then
      return
    fi

    var_warning "Waiting 5 minutes for rate limit, need ${WANTED_CALLS} requests"
    sleep 300
  done
}

github_repo_pr_stats() {
  meta_check "var"

  if [[ ${#} -ne 1 ]]; then
    var_red "Usage: github_repo_pr_stats GITHUB_REPOSITORY"
    return 1
  fi

  local GITHUB_REPOSITORY="${1}"
  shift

  local pr_page=0
  local pr_page_size=100
  local pr_count="${pr_page_size}"

  mkdir -p "${GITHUB_REPOSITORY}"

  while [[ pr_count -eq ${pr_page_size} ]]; do
    pr_page=$((pr_page + 1))

    var_info "Fetching page ${pr_page} of ${GITHUB_REPOSITORY} pull-requests"

    github_rate_limit_wait
    http_request "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls?state=closed&per_page=${pr_page_size}&page=${pr_page}"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to list ${GITHUB_REPOSITORY} pull-requests on page ${pr_page}"
      http_reset
      break
    fi

    pr_count="$(jq --raw-output 'length' "${HTTP_OUTPUT}")"
    if [[ ${pr_count} -eq 0 ]]; then
      rm "${HTTP_OUTPUT}"
      break
    fi

    local PULL_REQUESTS
    mapfile -t PULL_REQUESTS < <(jq --raw-output '. [] | select(.merged_at != null) | select(.user.login != null) | (.number | tostring) + "," + .user.login' "${HTTP_OUTPUT}")
    rm "${HTTP_OUTPUT}"

    github_rate_limit_wait "${pr_page_size}"

    for PR in "${PULL_REQUESTS[@]}"; do
      local PR_NUMBER
      PR_NUMBER="$(printf '%s' "${PR}" | awk -F ',' '{ print $1 }')"
      local PR_AUTHOR
      PR_AUTHOR="$(printf '%s' "${PR}" | awk -F ',' '{ print $2 }')"

      http_request "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/reviews"
      if [[ ${HTTP_STATUS} != "200" ]]; then
        http_handle_error "Unable to fetch ${GITHUB_REPOSITORY}/pulls/${PR_NUMBER} reviews"
        break
      fi

      jq --compact-output --raw-output --arg author "${PR_AUTHOR}" '[.[] | select(.user.login != null) | .user.login] | {$author, reviewers: .}' "${HTTP_OUTPUT}" >"${GITHUB_REPOSITORY}/${PR_NUMBER}.json"
    done
  done

  jq --slurp --compact-output --raw-output '
    [group_by(.author) | .[] | { author: (.[0].author), opened: length }] +
    [ [.[].reviewers] | flatten | group_by(.) | .[] | { author: .[0], reviewed: length}] |
    [reduce .[] as $o ({}; .[$o["author"] | tostring] += $o ) | .[]]' "${GITHUB_REPOSITORY}/"*.json

  rm -r "${GITHUB_REPOSITORY:?}/"
}

github_repo_stats() {
  meta_check "var" "http"

  if [[ ${#} -ne 1 ]]; then
    var_red "Usage: github_repo_stats GITHUB_REPOSITORY"
    return 1
  fi

  local GITHUB_REPOSITORY="${1}"
  shift

  local retry="true"
  local retryCount=0

  while [[ ${retry} == "true" ]]; do
    github_rate_limit_wait

    http_request "https://api.github.com/repos/${GITHUB_REPOSITORY}/stats/contributors"
    if [[ ${HTTP_STATUS} == "202" ]]; then
      var_warning "Contributions are being compiled for ${GITHUB_REPOSITORY}, waiting 30 seconds"
      rm "${HTTP_OUTPUT}"
      sleep 30

      retryCount=$((retryCount + 1))

      if [[ ${retryCount} -gt 10 ]]; then
        var_error "Contributions cannot be compiled, ignoring repo"
        return 1
      fi

      continue
    fi

    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to get contributors' stats for ${GITHUB_REPOSITORY}"
      http_reset
      return 1
    fi

    retry="false"

    local stats
    stats="$(jq --compact-output --raw-output --arg repo "${GITHUB_REPOSITORY}" \
      '{
        repository: $repo,
        contributors: [.[] | {author: .author.login, added: (reduce .weeks[] as $item (0; . + $item.a)), deleted: (reduce .weeks[] as $item (0; . + $item.d)), commits: (reduce .weeks[] as $item (0; . + $item.c))} | {author, added, deleted, commits, ratio: (.added - .deleted), mean_by_commit: ((.added - .deleted) / .commits) | floor }] | sort_by(.author)
      }' \
      "${HTTP_OUTPUT}")"
    rm "${HTTP_OUTPUT}"

    local prs
    prs="$(github_repo_pr_stats "${GITHUB_REPOSITORY}")"

    printf -- "%s\n%s" "${stats}" "${prs}" | jq --compact-output --raw-output --slurp '{
      repository: .[0].repository,
      contributors: ((.[0] | .contributors) + .[1] | [reduce .[] as $o ({}; .[$o["author"] | tostring] += $o ) | .[]] | sort_by(.author))
    }'
  done
}

github_org_stats() {
  meta_check "var" "http"

  if [[ ${#} -lt 1 ]]; then
    var_red "Usage: github_org_stats GITHUB_ORGANIZATION [REPOSITORY_FILTER_REGEX]"
    return 1
  fi

  local GITHUB_ORGANIZATION="${1-}"
  shift
  local REPOSITORY_FILTER_REGEX="${1:-.*}"
  shift || true

  local repo_page=0
  local repo_page_size=100
  local repo_count="${repo_page_size}"

  mkdir -p "${GITHUB_ORGANIZATION}"

  while [[ repo_count -eq ${repo_page_size} ]]; do
    repo_page=$((repo_page + 1))

    github_rate_limit_wait

    http_request "https://api.github.com/orgs/${GITHUB_ORGANIZATION}/repos?per_page=${repo_page_size}&page=${repo_page}"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to list ${GITHUB_ORGANIZATION} repositories on page ${repo_page}"
      http_reset
      break
    fi

    repo_count="$(jq --raw-output 'length' "${HTTP_OUTPUT}")"
    if [[ ${repo_count} -eq 0 ]]; then
      rm "${HTTP_OUTPUT}"
      break
    fi

    local REPOSITORIES
    mapfile -t REPOSITORIES < <(jq --compact-output --raw-output --arg filter "${REPOSITORY_FILTER_REGEX}" '.[] | select(.full_name | test($filter)) | .full_name' "${HTTP_OUTPUT}")
    rm "${HTTP_OUTPUT}"

    for REPO in "${REPOSITORIES[@]}"; do
      var_info "Generating stats for ${REPO}"
      github_repo_stats "${REPO}" >"${REPO}.json"
    done
  done

  jq '.' --slurp "${GITHUB_ORGANIZATION}/"*.json >"${GITHUB_ORGANIZATION}.json"

  rm -r "${GITHUB_ORGANIZATION}"
  http_reset
}

github_org_stats_user() {
  meta_check "var"

  if [[ ${#} -ne 2 ]]; then
    var_red "Usage: github_org_stats_user github_org_stats.json GITHUB_USER"
    return 1
  fi

  local FILENAME="${1-}"
  shift || true
  local GITHUB_USER="${1-}"
  shift || true

  local GITHUB_USER_STATS
  GITHUB_USER_STATS="$(jq --compact-output --raw-output --arg user "${GITHUB_USER}" '[.[] | {repository, contribution: .contributors[] | select(.author == $user)}] | sort_by(.contribution.ratio)' "${FILENAME}")"

  printf -- "%s\n" "${GITHUB_USER_STATS}"
  printf -- "%s" "${GITHUB_USER_STATS}" | jq '{added: (reduce .[].contribution as $contrib (0; . + $contrib.added)), deleted: (reduce .[].contribution as $contrib (0; . + $contrib.deleted)), commits: (reduce .[].contribution as $contrib (0; . + $contrib.commits)), opened: (reduce .[].contribution as $contrib (0; . + $contrib.opened)), reviewed: (reduce .[].contribution as $contrib (0; . + $contrib.reviewed))} | {added: .added, deleted: .deleted, commits: .commits, opened: .opened, reviewed: .reviewed, ratio: (.added - .deleted), mean_by_commit: ((.added - .deleted) / ([.commits, 1] | max)) | floor}'
}

github_clone() {
  meta_check "var" "http"

  github_http_init

  http_request "https://api.github.com/user/orgs"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to list user organizations"
    return 1
  fi

  local USER_ORGANIZATIONS
  USER_ORGANIZATIONS="$(jq --raw-output '.[].login' "${HTTP_OUTPUT}")"
  rm "${HTTP_OUTPUT}"

  http_request "https://api.github.com/user"
  if [[ ${HTTP_STATUS} != "200" ]]; then
    http_handle_error "Unable to get user information"
    http_reset
    return 1
  fi

  local USERNAME
  USERNAME="$(jq --raw-output '.login' "${HTTP_OUTPUT}")"
  rm "${HTTP_OUTPUT}"

  printf -v USER_ORGANIZATIONS -- "%s\n%s" "${USER_ORGANIZATIONS}" "${USERNAME}"

  local GITHUB_ORGANIZATION
  GITHUB_ORGANIZATION="$(printf -- "%s" "${USER_ORGANIZATIONS}" | fzf --height=20 --ansi --reverse --select-1 --query="${1-}" --prompt="Organization:")"

  local page=0
  local page_size=100
  local count="${page_size}"

  local scope="user"
  if [[ ${GITHUB_ORGANIZATION} != "${USERNAME}" ]]; then
    scope="orgs/${GITHUB_ORGANIZATION}"
  fi

  local REPOSITORY_REGEX="${2-}"
  var_read REPOSITORY_REGEX ""

  while [[ count -eq ${page_size} ]]; do
    page=$((page + 1))

    http_request --header "Content-Type: application/json" "https://api.github.com/${scope}/repos?type=owner&per_page=${page_size}&page=${page}"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to list user repositories on page ${page}"
      http_reset
      return 1
    fi

    count="$(jq --raw-output 'length' "${HTTP_OUTPUT}")"
    if [[ ${count} -eq 0 ]]; then
      rm "${HTTP_OUTPUT}"
      break
    fi

    local REPOSITORIES
    mapfile -t REPOSITORIES < <(jq --raw-output '.[] | select (.archived | not) | .name + "," + .ssh_url' "${HTTP_OUTPUT}")
    rm "${HTTP_OUTPUT}"

    for REPO in "${REPOSITORIES[@]}"; do
      local REPO_NAME
      REPO_NAME="$(printf '%s' "${REPO}" | awk -F ',' '{ print $1 }')"
      local REPO_SSH_URL
      REPO_SSH_URL="$(printf '%s' "${REPO}" | awk -F ',' '{ print $2 }')"

      if ! [[ ${REPO_NAME} =~ ${REPOSITORY_REGEX} ]]; then
        continue
      fi

      if [[ -d ${REPO_NAME} ]]; then
        var_success "${REPO_NAME} already cloned!"
      else
        var_info "Cloning ${REPO_NAME}"
        var_print_and_run git clone "${REPO_SSH_URL}" "${REPO_NAME}"
      fi
    done
  done

  http_reset
}

github_clean_subscription() {
  meta_check "var" "http"

  github_http_init

  local page=0
  local page_size=50
  local count="${page_size}"

  while [[ count -eq ${page_size} ]]; do
    page=$((page + 1))

    var_info "Fetching all subscriptions page ${page}..."

    http_request "https://api.github.com/notifications?all=true&per_page=${page_size}&page=${page}"
    if [[ ${HTTP_STATUS} != "200" ]]; then
      http_handle_error "Unable to list notifications on page ${page}"
      http_reset
      break
    fi

    count="$(jq --raw-output 'length' "${HTTP_OUTPUT}")"
    if [[ ${count} -eq 0 ]]; then
      rm "${HTTP_OUTPUT}"
      break
    fi

    local THREADS
    mapfile -t THREADS < <(jq --raw-output '.[].url' "${HTTP_OUTPUT}")
    rm "${HTTP_OUTPUT}"

    for THREAD in "${THREADS[@]}"; do
      http_request --request DELETE "${THREAD}/subscription"
      if [[ ${HTTP_STATUS} != "204" ]]; then
        http_handle_error "Unable to delete subscription for thread ${THREAD}"
        continue
      fi
      rm "${HTTP_OUTPUT}"
    done
  done

  http_reset
}

github_release() {
  meta_check "var" "git" "http"

  if ! git_is_inside; then
    var_warning "not inside a git tree"
    return 1
  fi

  var_info "Identifying semver"

  local LAST_TAG
  LAST_TAG="$(git_last_tag)"

  local VERSION_REF
  local PREVIOUS_REF

  if [[ -n ${LAST_TAG:-} ]]; then
    VERSION_REF="$(git log --no-merges --invert-grep --grep "\[skip ci\] Automated" --color --pretty=format:'%Cred%h%Creset%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' "HEAD...${LAST_TAG}" | fzf --height=20 --ansi --reverse | awk '{printf("%s", $1)}')"
    var_read PREVIOUS_REF "$(git tag --sort=-creatordate | grep --invert-match "${VERSION_REF}" | head -1)"
  else
    PREVIOUS_REF="HEAD^1"
    VERSION_REF="HEAD"
  fi

  local CHANGELOG
  CHANGELOG=$(git_changelog "${VERSION_REF}" "${PREVIOUS_REF}")
  printf -- "%bCHANGELOG:%b\n\n%s%b\n\n" "${YELLOW}" "${GREEN}" "${CHANGELOG}" "${RESET}"

  local VERSION_TYPE="patch"
  if [[ ${CHANGELOG} =~ \#\ BREAKING\ CHANGES ]]; then
    VERSION_TYPE="major"
  elif [[ ${CHANGELOG} =~ \#\ Features ]]; then
    VERSION_TYPE="minor"
  fi

  printf -- "%bRelease seems to be a %b%s%b\n" "${BLUE}" "${YELLOW}" "${VERSION_TYPE}" "${RESET}"
  var_info "Specify explicit git tag or major|minor|patch for semver increment"
  local VERSION
  VERSION="$(printf -- "%bpatch\n%bminor\n%bmajor" "${GREEN}" "${YELLOW}" "${RED}" | fzf --height=20 --ansi --reverse)"

  local GIT_TAG
  GIT_TAG="$(version_semver "${VERSION}" "${VERSION_REF}" "quiet")"

  var_read GITHUB_REPOSITORY "$(git_remote_repository)"
  var_read RELEASE_NAME "${GIT_TAG}"

  var_info "Creating release ${RELEASE_NAME} for ${GITHUB_REPOSITORY}..."

  http_init_client --header "Authorization: token $(github_token)" --header "Accept: application/vnd.github+json" --header "X-GitHub-Api-Version: 2022-11-28"
  HTTP_CLIENT_ARGS+=("--max-time" "120")

  local PAYLOAD
  PAYLOAD="$(jq --compact-output --null-input \
    --arg tag "${RELEASE_NAME}" \
    --arg target "$(git rev-parse "${VERSION_REF}")" \
    --arg name "${RELEASE_NAME}" \
    --arg body "${CHANGELOG}" \
    '{tag_name: $tag, target_commitish: $target, name: $name, body: $body}')"

  http_request --request "POST" "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" --data "${PAYLOAD}"
  if [[ ${HTTP_STATUS} != "201" ]]; then
    http_handle_error "Unable to create release"
    http_reset
    return 1
  fi
  rm "${HTTP_OUTPUT}"

  http_reset

  var_success "${GITHUB_REPOSITORY}@${RELEASE_NAME} created!"

  unset GITHUB_REPOSITORY
  unset RELEASE_NAME
}

github_compare_version() {
  meta_check "var"

  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: github_compare_version GITHUB_REPOSITORY LATEST_VERSION [CURRENT_VERSION] [RELEASE_API_FILE]"
    return 1
  fi

  local GITHUB_REPOSITORY="${1}"
  shift
  local LATEST_VERSION="${1}"
  shift
  local CURRENT_VERSION="${1-}"
  shift || true
  local RELEASE_API_FILE="${1-}"
  shift || true

  if [[ -z ${CURRENT_VERSION} ]]; then
    printf -- "%s" "${LATEST_VERSION}"
    rm "${RELEASE_API_FILE}"
    return
  fi

  if [[ ${CURRENT_VERSION} == "${LATEST_VERSION}" ]]; then
    var_success "${GITHUB_REPOSITORY} is up to date ${LATEST_VERSION}!"
    rm "${RELEASE_API_FILE}"
    return
  fi

  local RELEASE_NOTES
  RELEASE_NOTES="$(jq --raw-output .body "${RELEASE_API_FILE}")"
  rm "${RELEASE_API_FILE}"

  printf -- "%b%s%b: current version is %b%s%b, new version is %b%s%b %s%b\n" "${GREEN}" "${GITHUB_REPOSITORY}" "${BLUE}" "${RED}" "${CURRENT_VERSION}" "${BLUE}" "${YELLOW}" "${LATEST_VERSION}" "${GREEN}" "https://github.com/${GITHUB_REPOSITORY}/releases/tag/${LATEST_VERSION}" "${RESET}"
  printf -- "%s\n" "${RELEASE_NOTES}"
}

github_pull_request() {
  meta_check "var" "http"

  if [[ ${#} -lt 4 ]]; then
    var_red "Usage: github_pull_request GITHUB_REPOSITORY TITLE BASE HEAD BODY?"
    return 1
  fi

  local GITHUB_REPOSITORY="${1-}"
  shift

  local PR_TITLE="${1-}"
  shift

  local PR_BASE="${1-}"
  shift

  local PR_HEAD="${1-}"
  shift

  local PR_BODY="${1-}"
  shift || true

  github_http_init

  http_request \
    --request "POST" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls" \
    --data "$(
      jq --compact-output --null-input \
        --arg title "${PR_TITLE}" \
        --arg base "${PR_BASE}" \
        --arg head "${PR_HEAD}" \
        --arg body "${PR_BODY}" \
        '{title: $title, base: $base, head: $head, body: $body}'
    )"
  if [[ ${HTTP_STATUS} != "201" ]]; then
    http_handle_error "Unable to create pull request for ${PR_HEAD}"
    http_reset
    return 1
  fi

  jq --raw-output '.html_url' "${HTTP_OUTPUT}"
  http_reset
}
