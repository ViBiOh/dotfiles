# dotfiles

## Installation

```bash
mkdir -p ${HOME}/code/
pushd ${HOME}/code/
git clone https://github.com/ViBiOh/dotfiles.git
./dotfiles/init.sh
popd
```

### Configuration

You can set following environment variables for customizing installation behavior:

* `DOTFILES_NO_NODE="true"` doesn't perform install of `install/node` file (replace `NODE` by any uppercase filename in `install/` dir)

```bash
#!/usr/bin/env bash
# Server configuration example

export DOTFILES_NO_ALACRITTY="true"
export DOTFILES_NO_GOLANG="true"
export DOTFILES_NO_GPG="true"
export DOTFILES_NO_KUBERNETES="true"
export DOTFILES_NO_NODE="true"
export DOTFILES_NO_PASS="true"
export DOTFILES_NO_PYTHON="true"
export DOTFILES_NO_PYTHON_ANSIBLE="true"
export DOTFILES_NO_PYTHON_ASCIINEMA="true"
export DOTFILES_NO_PYTHON_PGCLI="true"
export DOTFILES_NO_SHELLCHECK="true"
export DOTFILES_NO_SUBLIME_TEXT="true"
export DOTFILES_NO_SYNCTHING="true"
export DOTFILES_NO_TERRAFORM="true"
```

## SSH

```bash
ssh-keygen -t ed25519 -a 100 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519
```

## Brew

Fix it with following command when it's broken.

```bash
sudo chown -R "$(whoami)" "$(brew --prefix)"/*
brew doctor
```
