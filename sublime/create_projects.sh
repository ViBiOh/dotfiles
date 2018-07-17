#!/usr/bin/env bash

mkdir -p projects

for project in ${HOME}/code/src/github.com/ViBiOh/*; do
  projectName=`basename ${project}`
  fileName="./projects/${projectName}.sublime-project"

  cat > "${fileName}" <<DELIM
{
  "folders": [{
      "path": "/Users/vibioh/code/src/github.com/ViBiOh/${projectName}"
  }]
}
DELIM

  subl --project "${fileName}"

done
