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

## Golang

### Binary

[Install latest version](https://golang.org/dl/)

### go-torch

```
go get -u github.com/uber/go-torch
cd $GOPATH/src/github.com/uber/go-torch
git clone https://github.com/brendangregg/FlameGraph.git
```
