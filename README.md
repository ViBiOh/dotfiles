# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone git@github.com:ViBiOh/dotfiles.git
./dotfiles/install.sh
```

## SSH

### Generate key and deploy key

```bash
ssh-keygen -t ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub docker
```

## Brew

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

## CoreOS

```bash
toolbox dnf -y install htop bash-completion
toolbox cp /usr/share/bash-completion /media/root/var/ -R
```

## Bash

```bash
brew install bash bash-completion
```

Then change default bash for root

```bash
sudo -s
echo /usr/local/bin/bash >> /etc/shells
chsh -s /usr/local/bin/bash
```

And also for current user

```bash
chsh -s /usr/local/bin/bash
```

## Git with fswatch

```bash
brew install fswatch
```

## TL;DR

```bash
brew install tldr
```

## tmux

```bash
brew install tmux
brew install reattach-to-user-namespace
```

### on Linux

```bash
sudo apt-get install -y tmux
```

## FZF

```bash
brew install fzf
/usr/local/opt/fzf/install
```

### on Linux

```bash
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

## Node

### Binary

[Install latest version](https://nodejs.org/en/download/)

### Node tools

```bash
npm i -g npm
npm i -g n
sudo n latest
```

## Golang

### Binary

[Install latest version](https://golang.org/dl/)

### tools

```bash
go get -u github.com/golang/lint/golint
go get -u golang.org/x/tools/cmd/goimports
go get -u github.com/nsf/gocode
go get -u github.com/golang/dep/cmd/dep
go get -u github.com/derekparker/delve/cmd/dlv
```

