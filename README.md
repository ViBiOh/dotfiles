# dotfiles

## Installation

```
mkdir -p ${HOME}/code/src/github.com/ViBiOh/
pushd ${HOME}/code/src/github.com/ViBiOh/
git clone --depth 1 https://github.com/ViBiOh/dotfiles.git
./dotfiles/install.sh
popd
```

### Configuration

You can set followin environment variables for customizing installation behavior:

* `DOTFILES_CLEAN="true"` will perform a clean before installation (deleting `${HOME}/opt` dir)
* `DOTFILES_NO_SUDO="true"` will doesn't perform `sudo` command

## SSH

```bash
ssh-keygen -t ed25519 -a 100 -C "`whoami`@`hostname`" -f ~/.ssh/id_ed25519
```

## Brew

Fix it with following command when it's broken.

```bash
sudo chown -R `whoami` $(brew --prefix)/*
brew doctor
```
