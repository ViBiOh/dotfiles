#!/usr/bin/env bash

set -e
set -u

mkdir -p projects

for project in ${HOME}/code/src/github.com/ViBiOh/*; do
  projectName=`basename ${project}`
  fileName="./projects/${projectName}.sublime-project"

  cat > "${fileName}" <<DELIM
{
  "folders": [{
      "path": "${project}"
  }]
}
DELIM

  subl --project "${fileName}"

done
