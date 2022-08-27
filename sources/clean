#!/usr/bin/env bash

memory_clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo sync && sudo purge
  elif [[ $(sudo which sysctl | wc -l) -ne 0 ]] && [[ $(sudo sysctl -a 2>/dev/null | grep --count vm.drop_caches) -ne 0 ]]; then
    sudo sysctl vm.drop_caches=3
  else
    sudo sync
    printf "3\n" >"/proc/sys/vm/drop_caches"
  fi
}

os_clean() {
  rm -rf "${HOME}/.bash_history"
  rm -rf "${HOME}/.cache/"
  rm -rf "${HOME}/.CFUserTextEncoding"
  rm -rf "${HOME}/.cups/"
  rm -rf "${HOME}/.local/"

  macos_clean

  memory_clean
}

macos_clean() {
  sudo find / \( -name ".DS_Store" -or -name ".localized" \) -exec rm -f {} \; 2>/dev/null

  sudo rm -rfv /var/spool/cups/c0*
  sudo rm -rfv /var/spool/cups/tmp/*
  sudo rm -rfv /var/spool/cups/cache/job.cache*

  sudo rm -rfv /var/db/lockdown/*

  qlmanage -r cache

  clear_folder_and_lock "${HOME}/Library/Application Support/Quick Look/"*
  clear_folder_and_lock "${HOME}/Library/LanguageModeling/"*
  clear_folder_and_lock "${HOME}/Library/Spelling/"*
  clear_folder_and_lock "${HOME}/Library/Suggestions/"*
  clear_folder_and_lock "${HOME}/Library/Assistant/SiriAnalytics.db"
  clear_folder_and_lock "${HOME}/Library/Saved Application State/"*

  defaults delete com.apple.finder FXDesktopVolumePositions
  defaults delete com.apple.finder FXRecentFolders
  defaults delete com.apple.finder RecentMoveAndCopyDestinations
  defaults delete com.apple.finder RecentSearches
  defaults delete com.apple.finder SGTRecentFileSearches

  defaults delete com.apple.iPod "conn:128:Last Connect"
  defaults delete com.apple.iPod Devices

  sudo defaults delete com.apple.Bluetooth DeviceCache
  sudo defaults delete com.apple.Bluetooth IDSPairedDevices
  sudo defaults delete com.apple.Bluetooth PANDevices
  sudo defaults delete com.apple.Bluetooth PANInterfaces
  sudo defaults delete com.apple.Bluetooth SCOAudioDevices
}

clear_folder_and_lock() {
  rm -rfv "${@}"
  chmod -R 000 "${@}"
  chflags -R uchg "${@}"
}

brew_clean_all() {
  brew remove --force "$(brew list)" --ignore-dependencies
  brew cleanup
}
