#!/usr/bin/env bash

if ! [[ ${OSTYPE} =~ ^darwin ]]; then
  return
fi

fix_spotlight() {
  sudo mdutil -a -d -i off
  sudo mdutil -X "/"
  sudo mdutil -X "/System/Volumes/Data"
}

fix_profile() {
  rm -rf "${HOME}/.profile" "${HOME}/.zprofile" "${HOME}/.zshrc"
}

macos_start() {
  fix_spotlight
  fix_profile

  if [[ ${DOTFILES_DNS:-} == "true" ]]; then
    dns_set "127.0.0.1"
  fi

  dns_flush

  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults write NSGlobalDomain com.apple.mouse.scaling -int 2
}
