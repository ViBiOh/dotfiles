#!/usr/bin/env bash

if ! command -v ansible >/dev/null 2>&1; then
  return
fi

export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_VAULT_PASSWORD_FILE="${HOME}/.ansible_vault_pass.sh"
