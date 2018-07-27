#!/usr/bin/env bash

set -e
set -u

mkdir -p projects

for folder in github.com/ViBiOh; do
  for project in ${HOME}/code/src/${folder}/*; do
    projectName=`basename ${project}`
    fileName="./projects/${projectName}.sublime-project"

    cat > "${fileName}" <<DELIM
{
  "folders": [{
      "path": "/Users/vibioh/code/src/${folder}/${projectName}"
  }]
}
DELIM

    subl --project "${fileName}"

  done
done
