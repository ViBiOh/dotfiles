#!/usr/bin/env bash

gh_switch_pr() {
  local PULL_REQUESTS
  PULL_REQUESTS="$(gh pr list --search "is:open is:pr review-requested:@me" --json 'additions,deletions,author,headRefName,title,updatedAt')"

  if [[ ${PULL_REQUESTS:-} == "[]" ]]; then
    var_warning "No pull request waiting for review"
    return 1
  fi

  local COLOR_GREEN COLOR_RED COLOR_YELLOW COLOR_PURPLE COLOR_RESET
  printf -v COLOR_GREEN '%b' "${GREEN}"
  printf -v COLOR_RED '%b' "${RED}"
  printf -v COLOR_YELLOW '%b' "${YELLOW}"
  printf -v COLOR_PURPLE '%b' "${PURPLE}"
  printf -v COLOR_RESET '%b' "${RESET}"

  local BRANCH
  BRANCH="$(jq --raw-output \
    --arg green "${COLOR_GREEN}" \
    --arg red "${COLOR_RED}" \
    --arg yellow "${COLOR_YELLOW}" \
    --arg purple "${COLOR_PURPLE}" \
    --arg reset "${COLOR_RESET}" \
    'sort_by(.updatedAt) | reverse | .[] | [
      .headRefName,
      "\($green)+\(.additions)\($reset) \($red)-\(.deletions)\($reset) \($yellow)\(.headRefName)\($reset) \($purple)\(.author.login)\($reset) \(.title)"
    ] | @tsv' <<<"${PULL_REQUESTS}" |
    fzf --ansi --reverse --height=20 --delimiter='\t' --with-nth='2..' |
    cut -f 1)"

  if [[ -z ${BRANCH} ]]; then
    return 0
  fi

  git checkout "${BRANCH}"
}
