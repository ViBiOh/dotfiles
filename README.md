# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone https://github.com/ViBiOh/dotfiles.git
./dotfiles/update.sh
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
echo /usr/local/bin/bash >> /etc/shells
chsh -s /usr/local/bin/bash
```

And also for current user

```bash
chsh -s /usr/local/bin/bash
```

## Brew

Fix it with following command when it's broken.

```bash
sudo chown -R `whoami` `brew --prefix`/*
brew doctor
```
