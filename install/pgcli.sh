#!/usr/bin/env bash

echo "----------"
echo "- Pgcli"
echo "----------"

pip install pgcli
mkdir -p "${HOME}/.config/pgcli"
ln -s "${HOME}/.pgclirc" "${HOME}/.config/pgcli/config"
