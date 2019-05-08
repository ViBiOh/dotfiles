#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  rm -rf projects
  mkdir -p projects

  for project in "${HOME}/code/"*; do
    projectName=$(basename ${project})
    fileName="./projects/${projectName}.sublime-project"

    echo "{
  \"folders\": [{
      \"path\": \"${project}\"
  }]
}" > "${fileName}"

    subl --project "${fileName}"
  done
}

main
