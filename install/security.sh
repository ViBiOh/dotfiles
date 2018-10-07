#!/usr/bin/env bash

set -e
set -u

echo '------------'
echo '- Security -'
echo '------------'

cat \
  <(curl "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts") \
  <(curl "https://someonewhocares.org/hosts/zero/hosts") \
  <(echo "0.0.0.0 cdn-eu.realytics.net") \
  <(echo "0.0.0.0 i.realytics.io") \
  <(echo "0.0.0.0 api.realytics.io") \
  <(echo "127.0.0.1 `hostname`") \
  | egrep -v '^\s*#' \
  | egrep -v '^$' \
  | sort \
  | uniq \
  | grep -v '0.0.0.0 twitter.com' \
  | grep -v '0.0.0.0 www.twitter.com' \
  | grep -v '0.0.0.0 abs.twimg.com' \
  | grep -v '0.0.0.0 pbs.twimg.com' \
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
  | sudo tee /etc/hosts > /dev/null

if [ `uname` == 'Darwin' ]; then
  curl -o "${HOME}/code/bin/stronghold" https://raw.githubusercontent.com/alichtman/stronghold/master/stronghold-script.sh
  chmod +x "${HOME}/code/bin/stronghold"

  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
  defaults write com.apple.CrashReporter DialogType none
  sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool YES
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

  sudo scutil --set ComputerName macbook
  sudo scutil --set LocalHostName macbook

  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off
  sudo pkill -HUP socketfilterfw

  chflags nohidden ~/Library

  csrutil status
fi
