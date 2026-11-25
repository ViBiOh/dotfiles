#!/usr/bin/env bash

set -o nounset -o pipefail

# Every guideline file must appear as a Read in the transcript before any .go edit.
READ_ALL_GUIDELINES='
  [
    .[]
    | (.message.content? // [])
    | if type == "array" then .[] else empty end
    | select(.type == "tool_use" and .name == "Read")
    | (.input.file_path // "")
  ] as $paths
  | ["SKILL\\.md", "concurrency\\.md", "idioms\\.md"]
  | all(.[]; . as $name | any($paths[]; test("go-review/" + $name + "$")))
'

main() {
  local input
  input="$(cat)"

  local file
  file="$(printf '%s' "${input}" | jq --raw-output '.tool_input.file_path // empty')"

  if [[ ${file} != *.go ]]; then
    exit 0
  fi

  local transcript
  transcript="$(printf '%s' "${input}" | jq --raw-output '.transcript_path // empty')"

  # Subagent Reads land in their own transcript, not in the main session one.
  local agent_id
  agent_id="$(printf '%s' "${input}" | jq --raw-output '.agent_id // empty')"

  if [[ -n ${agent_id} ]]; then
    transcript="${transcript%.jsonl}/subagents/agent-${agent_id}.jsonl"
  fi

  if [[ -n ${transcript} ]] && [[ -r ${transcript} ]]; then
    if jq --exit-status --slurp "${READ_ALL_GUIDELINES}" "${transcript}" >/dev/null 2>&1; then
      exit 0
    fi
  fi

  printf 'BLOCKED: read ~/.claude/skills/go-review/SKILL.md, concurrency.md and idioms.md before editing any .go file. Reading them after writing the code does not count. Read all three now, then retry the edit.\n' >&2
  exit 2
}

main
