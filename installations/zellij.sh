#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

clean() {
  rm -rf "${HOME}/.config/zellij/"
}

install() {
  if package_exists "zellij"; then
    packages_install "zellij"
  fi

  if ! command -v zellij 2>/dev/null 2>&1; then
    return
  fi

  mkdir -p "${HOME}/.config/zellij"

  echo 'keybinds clear-defaults=true {
    normal {
        bind "Super Shift n" { NewTab; }
        bind "Super Shift d" { NewPane "Down"; }
        bind "Super d" { NewPane "Right"; }

        bind "Ctrl f" { SwitchToMode "entersearch"; }

        bind "Super Shift b" { Detach; }
    }

    entersearch {
        bind "Enter" { SwitchToMode "search"; }
    }

    search {
        bind "Esc" { SwitchToMode "normal"; }

        bind "n" { Search "up"; }
        bind "p" { Search "down"; }
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
