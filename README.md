# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
cd ${HOME}/code/src/github.com/ViBiOh/
git clone https://github.com/ViBiOh/dotfiles.git
./dotfiles/install.sh
```

## SSH

### Generate key and deploy key

```bash
ssh-keygen -t ed25519
ssh-copy-id -i ${HOME}/.ssh/id_ed25519.pub docker
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
