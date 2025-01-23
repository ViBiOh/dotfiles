#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.config/zellij/"
}

install() {
  if package_exists "zellij"; then
    packages_install_desktop "zellij"
  fi

  mkdir -p "${HOME}/.config/zellij"

  echo 'keybinds clear-defaults=true {
    normal {
        bind "Super Shift d" { NewPane "Down"; }
        bind "Super d" { NewPane "Right"; }

        bind "Ctrl f" { SwitchToMode "entersearch"; }
    }

    entersearch {
        bind "Enter" { SwitchToMode "search"; }
    }

    search {
        bind "Esc" { SwitchToMode "normal"; }

        bind "n" { Search "up"; }
    }
}

simplified_ui true
pane_frames false
scroll_buffer_size 10000

disable_session_metadata true

ui {
    pane_frames {
        hide_session_name true
    }
}

' >"${HOME}/.config/zellij/config.kdl"
}
