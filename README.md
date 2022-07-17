# dotfiles

[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=ViBiOh_dotfiles&metric=alert_status)](https://sonarcloud.io/dashboard?id=ViBiOh_dotfiles)

## How it works?

Please have a look at my article [here](https://dev.to/vibioh/dotfiles-5695)

## Installation

```bash
curl "https://dotfiles.vibioh.fr/bootstrap" | bash
```

## Update

```bash
"${HOME}/code/dotfiles/init" -a
```

## Configuration

You can set following environment variables for customizing installation behavior:

- `DOTFILES_NO_NODE="true"` doesn't perform install of `install/node` file (replace `NODE` by any uppercase filename in `install/` dir)

```bash
#!/usr/bin/env bash

# Server configuration example

export DOTFILES_NO__MACOS="true"
export DOTFILES_NO_ALACRITTY="true"
export DOTFILES_NO_APPLE="true"
export DOTFILES_NO_DNS="true"
export DOTFILES_NO_DOCKER="true"
export DOTFILES_NO_FIREFOX="true"
export DOTFILES_NO_GOLANG="true"
export DOTFILES_NO_GPG="true"
export DOTFILES_NO_HIDAPITESTER="true"
export DOTFILES_NO_JSONNET="true"
export DOTFILES_NO_KUBERNETES="true"
export DOTFILES_NO_MINIO="true"
export DOTFILES_NO_NODE="true"
export DOTFILES_NO_PASS="true"
export DOTFILES_NO_PYTHON="true"
export DOTFILES_NO_PYTHON_ANSIBLE="true"
export DOTFILES_NO_PYTHON_IREDIS="true"
export DOTFILES_NO_PYTHON_PGCLI="true"
export DOTFILES_NO_SHELLCHECK="true"
export DOTFILES_NO_SUBLIME="true"
export DOTFILES_NO_SYNCTHING="true"
export DOTFILES_NO_TERRAFORM="true"
```

## SSH

```bash
ssh-keygen -t ed25519 -a 100 -C "$(whoami)@$(hostname)" -f "${HOME}/.ssh/id_ed25519"
```

## GPG

```bash
gpg --full-generate-key
```

## Command Line Tools (macOS)

Reinstall them by running following command:

```bash
sudo rm -rf $(xcode-select -print-path)
xcode-select --install
```

### Brew

Fix it with following command when it's broken.

```bash
sudo chown -R "$(whoami)" "$(brew --prefix)"/*
brew doctor
```
