#!/usr/bin/env bash

set -e
set -u

sudo sh -c "curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts \
  | grep -v '0.0.0.0 twitter.com' \
  | grep -v '0.0.0.0 www.twitter.com' \
  | grep -v '0.0.0.0 static.licdn.com' \
  | grep -v '0.0.0.0 www.linkedin.com' \
  | grep -v '0.0.0.0 rollbar.com' \
  | grep -v '0.0.0.0 www.rollbar.com' \
  | grep -v '0.0.0.0 api.rollbar.com' \
  | grep -v '0.0.0.0 cdn.rollbar.com' \
  | grep -v '0.0.0.0 docs.rollbar.com' \
  | grep -v '0.0.0.0 help.rollbar.com' \
  | grep -v '0.0.0.0 reddit.com' \
  | grep -v '0.0.0.0 www.reddit.com' \
  > /etc/hosts"

if [ `uname` == 'Darwin' ]; then
  if command -v pip > /dev/null 2>&1; then
    pip install stronghold
  fi

  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
  defaults write com.apple.CrashReporter DialogType none
  sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool YES
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

  chflags nohidden ~/Library

  csrutil status
fi
