#!/bin/sh

# Alias for dealing with sudo
alias fuck='sudo $(history -p \!\!)'

for file in $HOME/code/dotfiles/.*; do
  [[ -r "$file" ]] && [[ -f "$file" ]] && source "$file"
done
