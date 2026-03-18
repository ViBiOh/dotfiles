#!/usr/bin/env bash

memory_clean() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo sync && sudo purge
  elif [[ $(sudo which sysctl | wc -l) -ne 0 ]] && [[ $(sudo sysctl -a 2>/dev/null | grep --count vm.drop_caches) -ne 0 ]]; then
    sudo sysctl vm.drop_caches=3
  else
    sudo sync
    printf -- "3\n" >"/proc/sys/vm/drop_caches"
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
  sudo find . \( -name ".DS_Store" -or -name ".localized" \) -exec rm -f {} \; 2>/dev/null

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
  brew cleanup --prune 30
}

order_66() {
  var_confirm "Erase all data"

  sudo --reset-timestamp echo "Erasing..."

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    while IFS= read -r interface; do
      sudo networksetup -setdnsservers "${interface}" Empty
      sudo networksetup -setsearchdomains "${interface}" Empty
    done <<<"$(sudo networksetup -listallnetworkservices | tail +2)"
  fi

  _order_66_script_dir() {
    local FILE_SOURCE="${BASH_SOURCE[0]}"

    if [[ -L ${FILE_SOURCE} ]]; then
      dirname "$(readlink "${FILE_SOURCE}")"
    else
      (
        cd "$(dirname "${FILE_SOURCE}")" && pwd
      )
    fi
  }

  "$(_order_66_script_dir)/../init.sh" -c

  if [[ "$(type -t "ssh_agent_stop")" == "function" ]]; then
    ssh_agent_stop
  fi

  if [[ "$(type -t "gpg_agent_stop")" == "function" ]]; then
    gpg_agent_stop
  fi

  sudo rm -rf \
    "${HOME}/.ssh" \
    "${HOME}/.gnupg" \
    "${HOME}/.local" \
    "${HOME}/.localrc" \
    "${HOME}/.config" \
    "${HOME}/.bash_history" \
    "${HOME}/.bash_profile" \
    "${PASSWORD_STORE_DIR:-${HOME}/.password-store}" \
    "${HOME}/code" \
    "${HOME}/opt" \
    "${HOME}/workspace" \
    "${HOME}/Documents" \
    "${HOME}/Library/Application Support/Sublime Text/Local/*" \
    "${HOME}/Library/Application Support/Sublime Merge/Local/*"

  # Clean broken symlinks in home directory
  find "${HOME}" -maxdepth 1 -type l ! -exec test -e {} \; -exec rm {} \;

  if [[ -e "/opt/k3s/k3s-clean" ]]; then
    /opt/k3s/k3s-clean
  fi
}
