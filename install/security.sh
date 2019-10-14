#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  cat \
    <(curl -q -sS -L "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts") \
    <(curl -q -sS -L "https://someonewhocares.org/hosts/zero/hosts") \
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
    | grep -v "0.0.0.0 www.linkedin.com" \
    | grep -v "0.0.0.0 static.licdn.com" \
    | grep -v "0.0.0.0 media.licdn.com" \
    | grep -v "0.0.0.0 reddit.com" \
    | grep -v "0.0.0.0 www.reddit.com" \
    | grep -v "0.0.0.0 oauth.reddit.com" \
    | grep -v "0.0.0.0 www.redditstatic.com" \
    | grep -v "0.0.0.0 alb.reddit.com" \
    | grep -v "0.0.0.0 redditmedia.com" \
    | grep -v "0.0.0.0 www.redditmedia.com" \
    | grep -v "thumbs.redditmedia.com" \
    | grep -v "0.0.0.0 preview.redd.it" \
    | grep -v "0.0.0.0 external-preview.redd.it" \
    | grep -v "0.0.0.0 v.redd.it" \
    | grep -v "0.0.0.0 styles.redditmedia.com" \
    | grep -v "0.0.0.0 reddit.map.fastly.net" \
    | sudo tee /etc/hosts > /dev/null

  if command -v systemd > /dev/null 2>&1; then
    sudo systemctl enable systemd-resolved.service
  fi

  if [[ "$(type -t dns_flush_cache)" = "function" ]]; then
    dns_flush_cache
  fi

  if [[ "${OSTYPE}" =~ ^darwin ]]; then
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true

    defaults write com.apple.Safari SuppressSearchSuggestions -bool true
    defaults write com.apple.Safari UniversalSearchEnabled -bool false

    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0

    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

    defaults write com.apple.dock tilesize -int 36
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0
    defaults write com.apple.dock showhidden -bool true
    defaults write com.apple.dock hide-mirror -bool true
    defaults write com.apple.dock mineffect -string "scale"
    defaults write com.apple.dock minimize-to-application -bool true
    defaults write com.apple.dock launchanim -bool false

    defaults write com.apple.Safari HomePage -string "about:blank"
    defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
    defaults write com.apple.Safari ShowSidebarInTopSites -bool false
    defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2
    defaults write com.apple.Safari IncludeDevelopMenu -bool true

    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

    sudo systemsetup -setwakeonnetworkaccess off

    # Disable the sudden motion sensor as it’s not useful for SSDs
    sudo pmset -a sms 0

    sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

    sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0
    sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

    defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
    defaults write com.apple.CrashReporter DialogType none

    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

    defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
    defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

    defaults write com.apple.screencapture location -string "${HOME}/Downloads"
    defaults write com.apple.screencapture type -string "png"
    defaults write com.apple.screencapture disable-shadow -bool true

    sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2> /dev/null
    sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist

    sudo nvram SystemAudioVolume=" "
    sudo scutil --set ComputerName macbook
    sudo scutil --set HostName macbook
    sudo scutil --set LocalHostName macbook

    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off
    sudo pkill -HUP socketfilterfw

    chflags nohidden "${HOME}/Library"

    csrutil status
  fi
}
