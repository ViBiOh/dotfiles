#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf projects
mkdir -p projects

for project in "${HOME}/code/src/github.com/ViBiOh/"*; do
  projectName=$(basename ${project})
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
