#!/usr/bin/env sh

set -e

for file in ${HOME}/code/src/github.com/ViBiOh/dotfiles/symlinks/*; do
  [ -r "${file}" ] && [ -f "${file}" ] && rm -f ${HOME}/.`basename ${file}` && ln -s ${file} ${HOME}/.`basename ${file}`
done

echo 'Host *
    AddKeysToAgent yes
    ServerAliveInterval 300
    ServerAliveCountMax 2

Host example
    HostName example.domain
    User vibioh
' >> ${HOME}/.ssh/config


if [ `uname` == 'Darwin' ] && [ `which brew 2>/dev/null | wc -l` -eq 0 ]; then
  echo Installing brew
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  echo
  echo Installing common brew tools
  brew install bash bash-completion tldr fzf

  echo
  echo Configuring FZF
  /usr/local/opt/fzf/install

  echo
  echo Follow instruction in README for configuring bash
fi
