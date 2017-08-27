# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone git@github.com:ViBiOh/dotfiles.git
./dotfiles/install.sh
```

## FZF

```
brew install fzf
/usr/local/opt/fzf/install
```

## Golang

### go-torch

```
go get -u github.com/uber/go-torch
cd $GOPATH/src/github.com/uber/go-torch
git clone https://github.com/brendangregg/FlameGraph.git
```

## Vim

For MacOS :

```
brew install vim
sudo ln -s /usr/local/bin/vim /usr/local/bin/vi
```

### Vundle

```
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall
```

### ag

```
brew install the_silver_searcher
```

### Golang

```
vim +GoInstallBinaries +qall
```

### Tern

```
npm install --prefix ${HOME}/.vim/bundle/tern_for_vim
```

