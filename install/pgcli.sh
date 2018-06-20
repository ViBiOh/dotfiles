#!/usr/bin/env bash

echo "----------"
echo "- Pgcli  -"
echo "----------"

sudo pip install pgcli
mkdir -p "${HOME}/.config/pgcli"
ln -s "${HOME}/.pgclirc" "${HOME}/.config/pgcli/config"
