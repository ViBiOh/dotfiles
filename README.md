# dotfiles

## How it works?

Please have a look at my article [here](https://dev.to/vibioh/dotfiles-5695)

## Installation

```bash
curl "https://dotfiles.vibioh.fr/bootstrap.sh" | bash
```

## Update

```bash
"${HOME}/code/dotfiles/init.sh" -a
```

## Configuration

You can set following environment variables for customizing installation behavior:

- `DOTFILES_NO_NODE="true"` doesn't perform install of `installations/node` file (replace `NODE` by any uppercase filename in `installations/` dir)

```bash
#!/usr/bin/env bash

# Dotfiles configuration example for a server

export DOTFILES__SCRIPTS="true"
export DOTFILES_RIPGREP="true"
export DOTFILES_VIM="true"
export DOTFILES_YQ="true"
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
