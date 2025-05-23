#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

install() {
  if ! [[ ${OSTYPE} =~ ^darwin ]]; then
    return
  fi

  defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false
  defaults write NSGlobalDomain AppleFontSmoothing -int 1
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
  defaults write NSGlobalDomain AppleLanguages -array "en-US"
  defaults write NSGlobalDomain AppleLocale -string "en_US@currency=eur;rg=frzzzz"
  defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
  defaults write NSGlobalDomain AppleMetricUnits -bool true
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain com.apple.keyboard.fnState -int 1
  defaults write NSGlobalDomain com.apple.mouse.scaling -int 2
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write NSGlobalDomain com.apple.sound.beep.flash -int 0
  defaults write NSGlobalDomain com.apple.springing.delay -int 5
  defaults write NSGlobalDomain com.apple.springing.enabled -int 1
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults write NSGlobalDomain com.apple.trackpad.forceClick -int 1
  defaults write NSGlobalDomain com.apple.trackpad.scaling -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
  defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

  defaults write com.apple.HIToolbox AppleFnUsageType -int 0

  defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false
  defaults write com.apple.systempreferences DisableAutoLoginButtonIsHidden -bool true
  defaults write com.apple.systempreferences ShowAllMode -bool true

  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder DisableAllAnimations -bool true

  sudo defaults write com.apple.Safari AutoFillCreditCardData -bool false
  sudo defaults write com.apple.Safari AutoFillFromAddressBook -bool false
  sudo defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
  sudo defaults write com.apple.Safari AutoFillPasswords -bool false
  sudo defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
  sudo defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
  sudo defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false
  sudo defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles -bool false
  sudo defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false
  sudo defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled -bool false
  sudo defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true
  sudo defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2
  sudo defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false
  sudo defaults write com.apple.Safari HomePage -string "about:blank"
  sudo defaults write com.apple.Safari IncludeDevelopMenu -bool true
  sudo defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true
  sudo defaults write com.apple.Safari ShowFavoritesBar -bool false
  sudo defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
  sudo defaults write com.apple.Safari ShowSidebarInTopSites -bool false
  sudo defaults write com.apple.Safari SuppressSearchSuggestions -bool true
  sudo defaults write com.apple.Safari UniversalSearchEnabled -bool false
  sudo defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true
  sudo defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false
  sudo defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool false
  sudo defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
  sudo defaults write com.apple.Safari WebKitJavaEnabled -bool false
  sudo defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
  sudo defaults write com.apple.Safari WebKitPluginsEnabled -bool false
  sudo defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true

  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write com.apple.dock hide-mirror -bool true
  defaults write com.apple.dock largesize -int 128
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock mineffect -string "scale"
  defaults write com.apple.dock minimize-to-application -bool true
  defaults write com.apple.dock orientation -string "left"
  defaults write com.apple.dock showhidden -bool true
  defaults write com.apple.dock tilesize -int 36
  defaults write com.apple.dock wvous-tl-modifier -int 1048576
  defaults write com.apple.dock wvous-tr-modifier -int 1048576
  defaults write com.apple.dock wvous-bl-modifier -int 1048576
  defaults write com.apple.dock wvous-br-modifier -int 1048576
  defaults write com.apple.dock wvous-tl-corner -int 1
  defaults write com.apple.dock wvous-tr-corner -int 1
  defaults write com.apple.dock wvous-bl-corner -int 1
  defaults write com.apple.dock wvous-br-corner -int 1
  defaults write com.apple.dock "show-recents" -int 0
  defaults write com.apple.dock region -string "FR"
  killall Dock

  defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

  defaults write com.apple.ActivityMonitor ShowCategory -int 0
  defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
  defaults write com.apple.ActivityMonitor SortDirection -int 0

  defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
  defaults write com.apple.DiskUtility advanced-image-options -bool true

  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

  defaults write com.apple.CrashReporter DialogType none

  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

  defaults write com.apple.screencapture disable-shadow -bool true
  defaults write com.apple.screencapture location -string "${HOME}/Downloads"
  defaults write com.apple.screencapture show-thumbnail -bool false
  defaults write com.apple.screencapture type -string "png"

  defaults write com.apple.touchbar.agent PresentationModeGlobal "functionKeys"
  defaults write "Apple Global Domain" AppleInterfaceStyle "Dark"
  defaults write com.apple.menuextra.clock IsAnalo -int 1

  sudo systemsetup -setrestartfreeze on
  sudo systemsetup -setwakeonnetworkaccess off
  sudo systemsetup -f -setremotelogin off

  sudo pmset -a autopoweroff 0
  sudo pmset -a destroyfvkeyonstandby 1
  sudo pmset -a hibernatemode 0
  sudo pmset -a lidwake 1
  sudo pmset -a powernap 0
  sudo pmset -a sms 0
  sudo pmset -a standby 0
  sudo pmset -a standbydelay 0
  sudo pmset -a tcpkeepalive 0
  sudo pmset -b displaysleep 5
  sudo pmset -b sleep 10
  sudo pmset -c displaysleep 10
  sudo pmset -c sleep 15

  if command -v fix_spotlight >/dev/null 2>&1; then
    fix_spotlight || true
  fi

  sudo nvram SystemAudioVolume=" "

  if [[ -n ${DOTFILES_MACOS_USERNAME:-} ]]; then
    sudo scutil --set ComputerName "${DOTFILES_MACOS_USERNAME}"
    sudo scutil --set HostName "${DOTFILES_MACOS_USERNAME}"
    sudo scutil --set LocalHostName "${DOTFILES_MACOS_USERNAME}"
    sudo networksetup -setcomputername "${DOTFILES_MACOS_USERNAME}"
    sudo systemsetup -setcomputername "${DOTFILES_MACOS_USERNAME}"

    sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
    sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
    sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0
    sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true
    sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool false # required for AirDrop
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
    sudo pkill -HUP socketfilterfw
  fi

  chflags nohidden "${HOME}/Library"

  csrutil status
}
