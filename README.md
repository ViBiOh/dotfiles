# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone https://github.com/ViBiOh/dotfiles.git
./dotfiles/install.sh
```

## SSH

```bash
ssh-keygen -t ed25519 -a 100 -C "`whoami`@`hostname`" -f ~/.ssh/id_ed25519
```

## Bash

Then change default bash for root

```bash
sudo -s
echo $(brew --prefix)/bin/bash >> /etc/shells
chsh -s $(brew --prefix)/bin/bash
```

And also for current user

```bash
chsh -s $(brew --prefix)/bin/bash
```

## Brew

Fix it with following command when it's broken.

```bash
sudo chown -R `whoami` $(brew --prefix)/*
brew doctor
```
