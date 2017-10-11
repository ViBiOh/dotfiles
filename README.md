# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone git@github.com:ViBiOh/dotfiles.git
./dotfiles/install.sh
```

## Brew

```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

## FZF

```
brew install fzf
/usr/local/opt/fzf/install
```

## Node

### Binary

[Install latest version](https://nodejs.org/en/download/)

### Node tools

```
npm i -g npm
npm i -g n
sudo n latest
```

## Golang

### Binary

[Install latest version](https://golang.org/dl/)

### delve

```
go get -u github.com/derekparker/delve/cmd/dlv
```

### go-torch

```
go get -u github.com/uber/go-torch
cd $GOPATH/src/github.com/uber/go-torch
git clone https://github.com/brendangregg/FlameGraph.git
```

### wuzz

```
go get -u github.com/asciimoo/wuzz
```

## vim

Install Vundle

```
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```
