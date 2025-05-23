#!/usr/bin/env bash

if [[ -d "${HOME}/opt/go/bin" ]]; then
  export PATH="${HOME}/opt/go/bin:${PATH}"
fi

if ! command -v go >/dev/null 2>&1; then
  return
fi

export GOPATH="${HOME}/opt/gopath"
export PATH="${GOPATH}/bin:${PATH}"

alias pprof_http_cpu='go tool pprof -http localhost:12000 http://localhost:9999/debug/pprof/profile'
alias pprof_http_memory='go tool pprof -http localhost:12001 http://localhost:9999/debug/pprof/heap'
alias pprof_http_goroutine='go tool pprof -http localhost:12002 http://localhost:9999/debug/pprof/goroutine'

alias go_bench="go test -bench=. -benchmem -run='^$'"

if command -v fzf >/dev/null 2>&1; then
  go_bump() {
    local MODULE_TO_BUMP
    MODULE_TO_BUMP="$(go list -m -json all | jq --raw-output 'select(.Indirect != true) | .Path' | fzf --select-1 --query="${1-}")"

    if [[ -z ${MODULE_TO_BUMP} ]]; then
      return
    fi

    printf -- "MODULE=%s\n" "${MODULE_TO_BUMP}"
    local MODULE_VERSION=""

    local GITHUB_TOKEN
    GITHUB_TOKEN="$(github_token)"

    if [[ -z ${2-} ]] && [[ ${MODULE_TO_BUMP} =~ ^github.com\/([^\/]+)\/([^\/]+)(\/.+)?$ ]] && [[ -n ${GITHUB_TOKEN} ]]; then
      local REPOSITORY_NAME="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"

      MODULE_VERSION="$(
        cat \
          <(printf -- "latest\n") \
          <(curl --disable --silent --show-error --location --max-time 10 --header "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${REPOSITORY_NAME}/branches?per_page=100" | jq --raw-output '.[].name') \
          <(curl --disable --silent --show-error --location --max-time 10 --header "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${REPOSITORY_NAME}/tags?per_page=100" | jq --raw-output '.[].name') |
          fzf --height=20 --ansi --reverse
      )"
    else
      var_read MODULE_VERSION "${2:-latest}"
    fi

    if [[ -n ${MODULE_VERSION} ]]; then
      printf -- "MODULE_VERSION=%s\n" "${MODULE_VERSION}"
      MODULE_VERSION="@${MODULE_VERSION}"

      var_print_and_run go get -d "${MODULE_TO_BUMP}${MODULE_VERSION}"
    fi
  }
fi

go_mod_loop() {
  declare -A MODULES

  local CURRENT_MODULE
  CURRENT_MODULE="$(go mod edit -json | jq --raw-output '.Module.Path')"

  MODULES[${CURRENT_MODULE}]="true"

  for module in $(go mod graph | grep -i " ${CURRENT_MODULE}@"); do
    if [[ ${module} =~ ^(.*)@.* ]]; then
      if [[ -z ${MODULES[${BASH_REMATCH[1]}]} ]]; then
        local NEED_MODULE="${BASH_REMATCH[1]}"
        MODULES[${NEED_MODULE}]="true"

        local MOD_WHY
        MOD_WHY="$(go mod why -m "${NEED_MODULE}")"

        if ! [[ ${MOD_WHY} =~ \(main\ module\ does\ not\ need\ module ]]; then
          printf '%b%s creates an import loop%b\n%s\n' "${BLUE}" "${NEED_MODULE}" "${RESET}" "${MOD_WHY}"
        fi
      fi
    fi
  done
}

go_mod_local() {
  local MODULE_TO_LOCAL
  MODULE_TO_LOCAL="$(go list -m -json all | jq --arg currentModule "$(go mod edit -json | jq --raw-output '.Module.Path')" -r 'select(.Indirect != true and $currentModule != .Path) | .Path' | fzf --select-1 --query="${1-}")"

  if [[ -z ${MODULE_TO_LOCAL} ]]; then
    return
  fi

  if [[ $(go list -m -json "${MODULE_TO_LOCAL}" | jq --raw-output 'select(.Replace != null) | .Path' | wc -l) -gt 0 ]]; then
    printf -- "Module %s was already replaced, removing it..." "${MODULE_TO_LOCAL}"
    go mod edit -dropreplace="${MODULE_TO_LOCAL}"
    return
  fi

  local LOCAL_NAME
  LOCAL_NAME=$(basename "${MODULE_TO_LOCAL}")

  if [[ ${MODULE_TO_LOCAL} =~ (.*)(/v[0-9]+) ]]; then
    LOCAL_NAME="$(basename "${BASH_REMATCH[1]}")"
  fi

  go mod edit -replace="${MODULE_TO_LOCAL}=../${LOCAL_NAME}"
}

go_work_init() {
  rm go.work
  go work init .
  go work use -r .
}
