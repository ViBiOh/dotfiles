#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf "${HOME}/opt" "${HOME}/.config"
mkdir -p "${HOME}/opt/bin"
