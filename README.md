# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/ ${HOME}/code/bin/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone https://github.com/ViBiOh/dotfiles.git
./dotfiles/install.sh
```

## SSH

### Generate key and deploy key

```bash
ssh-keygen -t ed25519
```

## Bash

Then change default bash for root

```bash
sudo -s
echo `brew --prefix`/bin/bash >> /etc/shells
chsh -s `brew --prefix`/bin/bash
```

And also for current user

```bash
chsh -s `brew --prefix`/bin/bash
```

## Brew

Fix it with following command when it's broken.

```bash
sudo chown -R `whoami` `brew --prefix`/*
brew doctor
```
