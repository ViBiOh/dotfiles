#!/usr/bin/env bash

if command -v brew >/dev/null 2>&1; then
  if [[ -f "${BREW_PREFIX:-}/etc/bash_completion" ]]; then
    source "${BREW_PREFIX:-}/etc/bash_completion"
  fi
elif [[ -f /etc/bash_completion ]]; then
  source "/etc/bash_completion"
fi

# Fix minor spelling issues with `cd`
shopt -s cdspell

# history configuration
export HISTCONTROL=ignoreboth:erasedups
export LESSHISTFILE=/dev/null

# When the shell exits, append to the history file instead of overwriting it
shopt -s histappend

# Enter a folder name to `cd` to it
if [[ $(shopt | grep --count "autocd") -eq 1 ]]; then
  shopt -s autocd
fi

# Fix minor spelling issues for commands
if [[ $(shopt | grep --count "dirspell") -eq 1 ]]; then
  shopt -s dirspell
fi
