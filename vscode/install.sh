#!/usr/bin/env bash

code --install-extension alefragnani.project-manager
code --install-extension casualjim.gotemplate
code --install-extension dbaeumer.vscode-eslint
code --install-extension donjayamanne.githistory
code --install-extension dzannotti.vscode-babel-coloring
code --install-extension eamodio.gitlens
code --install-extension esbenp.prettier-vscode
code --install-extension joelday.docthis
code --install-extension lukehoban.go
code --install-extension PeterJausovec.vscode-docker

cp settings.json keybindings.json "${HOME}/Library/Application Support/Code/User/"
cp javascript.json go.json "${HOME}/Library/Application Support/Code/User/snippets/"

if command -v go > /dev/null 2>&1; then
  echo
  echo Updating golang packages

  go get -v -u github.com/derekparker/delve/cmd/dlv
fi
