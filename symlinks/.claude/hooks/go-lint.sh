#!/usr/bin/env bash

set -o nounset -o pipefail

readonly CONFIG="${HOME}/.claude/skills/go-review/golangci.yml"

# Only the edits since the last user prompt, so a finished Go task is not linted again on every later turn.
readonly EDITED_GO_FILES='
  ((map(.type == "user" and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) // 0) as $start
  | .[$start:][]
  | (.message.content? // [])
  | if type == "array" then .[] else empty end
  | select(.type == "tool_use" and (.name == "Edit" or .name == "Write" or .name == "MultiEdit"))
  | (.input.file_path // "")
  | select(endswith(".go"))
'

is_lintable() {
  local file="${1}"

  if [[ ${file} != *.go ]]; then
    return 1
  fi

  if [[ ! -f ${file} ]]; then
    return 1
  fi

  if grep --quiet --max-count=1 '^// Code generated .* DO NOT EDIT\.$' "${file}"; then
    return 1
  fi

  return 0
}

# Prints the findings and returns 1, or prints why the linter could not run and returns 2.
lint_dir() {
  local dir="${1}"

  local args=(run --config "${CONFIG}" --show-stats=false --allow-parallel-runners --timeout=150s --path-mode=abs --output.json.path=stdout)

  local base
  if base="$(git -C "${dir}" rev-parse --abbrev-ref origin/HEAD 2>/dev/null)"; then
    args+=("--new-from-merge-base=${base}")
  fi

  local output
  output="$(cd "${dir}" && golangci-lint "${args[@]}" . 2>&1)"
  local status="${?}"

  # The JSON report is printed on a single line, log lines start with level=.
  local report
  report="$(printf '%s\n' "${output}" | grep '^{' | tail -n 1)"

  local reason
  reason="$(printf '%s\n' "${output}" | grep --max-count=1 'level=error')"

  local compile_error
  compile_error="$(printf '%s' "${report}" | jq --raw-output 'first(.Issues[]? | select(.FromLinter == "typecheck") | .Text) // empty' 2>/dev/null)"

  if [[ -n ${compile_error} ]]; then
    printf '%s does not compile (%s)' "${dir}" "${compile_error}"
    return 2
  fi

  if [[ ${status} -eq 0 ]]; then
    return 0
  fi

  local findings
  findings="$(printf '%s' "${report}" | jq --raw-output '.Issues[]? | "\(.Pos.Filename):\(.Pos.Line):\(.Pos.Column): \(.Text) (\(.FromLinter))"' 2>/dev/null)"

  if [[ ${status} -eq 1 ]] && [[ -n ${findings} ]]; then
    printf '%s' "${findings}"
    return 1
  fi

  printf '%s could not be linted, exit code %s (%s)' "${dir}" "${status}" "${reason:-no error message}"
  return 2
}

post_tool_use() {
  local input="${1}"

  local file
  file="$(printf '%s' "${input}" | jq --raw-output '.tool_input.file_path // empty')"

  if ! is_lintable "${file}"; then
    return 0
  fi

  local output
  output="$(lint_dir "$(dirname "${file}")")"
  local status="${?}"

  if [[ ${status} -eq 1 ]]; then
    printf 'golangci-lint with the go-review config found issues, fix every one of them:\n%s\n' "${output}" >&2
    return 2
  fi

  if [[ ${status} -eq 2 ]]; then
    jq --null-input --arg context "golangci-lint ignored: ${output}. State in the final report that the linter was ignored for this package." \
      '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
  fi

  return 0
}

stop() {
  local input="${1}"

  # A second stop in a row means the findings could not be fixed, let the report explain them instead of looping.
  if [[ $(printf '%s' "${input}" | jq --raw-output '.stop_hook_active // false') == "true" ]]; then
    return 0
  fi

  local transcript
  transcript="$(printf '%s' "${input}" | jq --raw-output '.transcript_path // empty')"

  if [[ -z ${transcript} ]] || [[ ! -r ${transcript} ]]; then
    return 0
  fi

  local dirs=()
  local file

  while IFS= read -r file; do
    if is_lintable "${file}"; then
      dirs+=("$(dirname "${file}")")
    fi
  done < <(jq --slurp --raw-output "${EDITED_GO_FILES}" "${transcript}" 2>/dev/null | sort --unique)

  if [[ ${#dirs[@]} -eq 0 ]]; then
    return 0
  fi

  local findings=""
  local dir

  while IFS= read -r dir; do
    local output
    output="$(lint_dir "${dir}")"

    if [[ ${?} -eq 1 ]]; then
      findings+="${output}"$'\n'
    fi
  done < <(printf '%s\n' "${dirs[@]}" | sort --unique)

  if [[ -n ${findings} ]]; then
    jq --null-input --arg reason "golangci-lint with the go-review config still reports issues, fix every one of them before finishing:"$'\n'"${findings}" \
      '{decision: "block", reason: $reason}'
  fi

  return 0
}

main() {
  local input
  input="$(cat)"

  local event
  event="$(printf '%s' "${input}" | jq --raw-output '.hook_event_name // empty')"

  case "${event}" in
    PostToolUse)
      post_tool_use "${input}"
      ;;
    Stop)
      stop "${input}"
      ;;
  esac
}

main
