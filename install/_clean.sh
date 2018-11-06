#!/usr/bin/env bash

set -e
set -u

echo "---------"
echo "- Clean -"
echo "---------"

rm -rf "${HOME}/opt" "${HOME}/.config"
mkdir -p "${HOME}/opt/bin"
