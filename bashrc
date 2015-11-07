#!/bin/sh

for file in $HOME/code/dotfiles/.*; do
  [[ -r "$file" ]] && [[ -f "$file" ]] && source "$file"
done
