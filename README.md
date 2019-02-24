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

* `DOTFILES_NO_NODE="true"` doesn't perform install of `install/node` file (replace `NODE` by any filename in `install/` dir)

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
