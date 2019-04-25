#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

main() {
  cat \
    <(curl "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts") \
    <(curl "https://someonewhocares.org/hosts/zero/hosts") \
    <(echo "0.0.0.0 cdn-eu.realytics.net") \
    <(echo "0.0.0.0 i.realytics.io") \
    <(echo "0.0.0.0 api.realytics.io") \
    <(echo "0.0.0.0 lead-the-way.fr") \
    <(echo "0.0.0.0 www.lead-the-way.fr") \
    <(echo "0.0.0.0 gl.hostcg.com") \
    <(echo "127.0.0.1 $(hostname)") \
    | egrep -v '^\s*#' \
    | egrep -v '^$' \
    | sort \
    | uniq \
    | grep -v '0.0.0.0 www.linkedin.com' \
    | grep -v '0.0.0.0 static.licdn.com' \
    | grep -v '0.0.0.0 media.licdn.com' \
    | grep -v '0.0.0.0 reddit.com' \
    | grep -v '0.0.0.0 www.reddit.com' \
    | grep -v '0.0.0.0 oauth.reddit.com' \
    | grep -v '0.0.0.0 www.redditstatic.com' \
    | grep -v '0.0.0.0 alb.reddit.com' \
    | grep -v '0.0.0.0 redditmedia.com' \
    | grep -v '0.0.0.0 www.redditmedia.com' \
    | grep -v 'thumbs.redditmedia.com' \
    | grep -v '0.0.0.0 preview.redd.it' \
    | grep -v '0.0.0.0 external-preview.redd.it' \
    | grep -v '0.0.0.0 v.redd.it' \
    | grep -v '0.0.0.0 styles.redditmedia.com' \
    | grep -v '0.0.0.0 reddit.map.fastly.net' \
    | sudo tee /etc/hosts > /dev/null

  if command -v dnsFlushCache > /dev/null 2>&1; then
    dnsFlushCache
  fi

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    defaults write com.apple.Safari UniversalSearchEnabled -bool false
    defaults write com.apple.Safari SuppressSearchSuggestions -bool true
    defaults write com.apple.CrashReporter DialogType none

    sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool YES
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

    sudo nvram SystemAudioVolume=%01
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
}

main
