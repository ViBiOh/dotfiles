#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  local PROJECT_FOLDER="projects"

  rm -rf "${PROJECT_FOLDER}"
  mkdir -p "${PROJECT_FOLDER}"

  for project in "${HOME}/code/"*; do
    projectName="$(basename "${project}")"
    fileName="./${PROJECT_FOLDER}/${projectName}.sublime-project"

    echo "{
  \"folders\": [{
      \"path\": \"${project}\"
  }]
}" > "${fileName}"

    subl --project "${fileName}"
  done
}

main "${@:-}"
