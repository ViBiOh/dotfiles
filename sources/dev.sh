#!/usr/bin/env bash

script_dir() {
  local FILE_SOURCE="${BASH_SOURCE[0]}"

  if [[ -L ${FILE_SOURCE} ]]; then
    dirname "$(readlink "${FILE_SOURCE}")"
  else
    (
      cd "$(dirname "${FILE_SOURCE}")" && pwd
    )
  fi
}

DOTFILES_SCRIPT_DIR="$(script_dir)"

alias dev='cd ${HOME}/code/'
alias work='test -e ${HOME}/workspace/ && cd ${HOME}/workspace/ || dev'
alias grep='grep --color=auto'
alias vi='vim'
alias fuck='sudo $(history -p \!\!)'

export EDITOR='vim'
export TERM='xterm-256color'

if command -v xdg-open >/dev/null 2>&1 && ! command -v open >/dev/null 2>&1; then
  alias open='xdg-open'
fi

figmoji() {
  figlet -f banner "${1:-Hello}" | tail -n +1 | head -n -1 | sed -e"s|#|:${2:-wave}:|g" | sed -e's| |:empty:|g' | pbcopy
}

qrcode() {
  qrencode -t UTF8
}

qrcode_wifi() {
  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: qrcode_wifi SSID PASSWORD"
    return 1
  fi

  local WIFI_NAME
  WIFI_NAME="${1}"

  local WIFI_PASSWORD
  WIFI_PASSWORD="${2}"

  WIFI_PASSWORD="${WIFI_PASSWORD//;/\\;}"
  WIFI_PASSWORD="${WIFI_PASSWORD//:/\\:}"

  printf -- "WIFI:T:WPA;R:1;S:%s;P:%s;;" "${WIFI_NAME}" "${WIFI_PASSWORD}" | qrcode
}

loop() {
  if [[ ${#} -lt 1 ]]; then
    var_red "Usage: 'loop command' [interval?(default 60s)]"
    return 1
  fi

  while true; do
    eval "${1}"

    var_info "Ended at $(date), next in ${2:-60} seconds"
    sleep "${2:-60}"
  done
}

dot_env() {
  local DOTENV_FILE="${1:-.env}"

  if [[ -e ${DOTENV_FILE} ]]; then
    comm -13 \
      <(make --directory "${DOTFILES_SCRIPT_DIR}/DotEnv/" | sort) \
      <(make --directory "${DOTFILES_SCRIPT_DIR}/DotEnv/" TARGET_ENV_FILE="$(readlink -f "${DOTENV_FILE}")" | sort) |
      grep -E -v "^(CURDIR|GNUMAKEFLAGS|MAKEFILE_LIST|MAKEFLAGS|TARGET_ENV_FILE)="
  fi
}

dot_env_json() {
  dot_env "${@}" | jq --null-input --raw-input '
def parse: capture("(?<key>[^=]*)=(?<value>.*)");

reduce inputs as $line ({};
  ($line | parse) as $p | .[$p.key] = ($p.value)
)
'
}

urlencode() {
  local old_lc_collate="${LC_COLLATE-}"
  LC_COLLATE="C"

  local length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:i:1}"
    case "${c}" in
    [a-zA-Z0-9.~_-]) printf -- "%s" "${c}" ;;
    ' ') printf -- "%%20" ;;
    *) printf '%%%02X' "'$c" ;;
    esac
  done

  LC_COLLATE="${old_lc_collate}"
}

my_ip() {
  var_info "IPv4: $(curl --disable --silent --show-error --location --max-time 30 -4 "https://ifconfig.co/ip")"
  var_info "IPv6: $(curl --disable --silent --show-error --location --max-time 30 -6 "https://ifconfig.co/ip")"
}

meteo() {
  curl --disable --silent --show-error --location --max-time 30 -4 "wttr.in/$(urlencode "${1:-Paris}")?m&format=v2"
}

stock() {
  local HEADER_OUTPUT
  HEADER_OUTPUT=$(mktemp)

  local YAHOO_OUTPUT
  YAHOO_OUTPUT="$(
    curl \
      --disable \
      --silent \
      --show-error \
      --location \
      --max-time 10 \
      --header "User-Agent: Mozilla/5.0" \
      --dump-header "${HEADER_OUTPUT}" \
      --fail-with-body \
      "https://query1.finance.yahoo.com/v8/finance/chart/${1:-DDOG}?&includePrePost=true&interval=1h&range=1d"
  )"

  if [[ ${?} -ne 0 ]]; then
    cat "${HEADER_OUTPUT}" >/dev/stderr
    printf -- "%s\n" "${YAHOO_OUTPUT}" >/dev/stderr
    rm -f "${HEADER_OUTPUT}"
    return 1
  fi

  rm -f "${HEADER_OUTPUT}"

  local STOCK_SYMBOL
  STOCK_SYMBOL="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta | .symbol')"

  local STOCK_CURRENCY
  STOCK_CURRENCY="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta | .currency')"

  local EVOLUTION_PERCENT
  local OUTPUT_COLOR
  local EVOLUTION_SIGN

  _stock_evolution() {
    EVOLUTION_PERCENT="$(printf -- "scale = 4; 100 * ((%s / %s) - 1)" "${CURRENT_PRICE}" "${PREVIOUS_PRICE}" | bc)"

    OUTPUT_COLOR="${GREEN}"
    EVOLUTION_SIGN="↗"

    if [[ ${EVOLUTION_PERCENT} =~ ^- ]]; then
      OUTPUT_COLOR="${RED}"
      EVOLUTION_SIGN="↘"
      EVOLUTION_PERCENT="${EVOLUTION_PERCENT#-}"
    elif [[ ${EVOLUTION_PERCENT} == 0 ]]; then
      OUTPUT_COLOR=""
      EVOLUTION_SIGN="→"
    fi
  }

  local CURRENT_PRICE
  local PREVIOUS_PRICE

  CURRENT_PRICE="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta | .regularMarketPrice')"
  PREVIOUS_PRICE="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta | .previousClose')"

  _stock_evolution
  printf -- "%b%s%b %s %s %b%s%s%b" "${YELLOW}" "${STOCK_SYMBOL}" "${RESET}" "${CURRENT_PRICE}" "${STOCK_CURRENCY}" "${OUTPUT_COLOR}" "${EVOLUTION_SIGN}" "${EVOLUTION_PERCENT%00}%" "${RESET}"

  local REGULAR_START
  REGULAR_START=$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta.currentTradingPeriod.regular.start')

  local REGULAR_END
  REGULAR_END=$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta.currentTradingPeriod.regular.end')

  local CURRENT_TIMESTAMP
  CURRENT_TIMESTAMP="$(date +%s)"

  if [[ ${CURRENT_TIMESTAMP} -lt ${REGULAR_START} ]] || [[ ${CURRENT_TIMESTAMP} -gt ${REGULAR_END} ]]; then
    CURRENT_PRICE="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].indicators.quote[0].open[-1]')"
    PREVIOUS_PRICE="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta | .regularMarketPrice')"

    _stock_evolution
    printf -- " | Pre %s %b%s%s%b" "${CURRENT_PRICE}" "${OUTPUT_COLOR}" "${EVOLUTION_SIGN}" "${EVOLUTION_PERCENT%00}%" "${RESET}"
  fi

  printf -- "\n"

  if command -v spark >/dev/null 2>&1; then
    YAHOO_OUTPUT="$(
      curl \
        --disable \
        --silent \
        --show-error \
        --location \
        --max-time 10 \
        --header "User-Agent: Mozilla/5.0" \
        --dump-header "${HEADER_OUTPUT}" \
        --fail-with-body \
        "https://query1.finance.yahoo.com/v8/finance/chart/${1:-DDOG}?&includePrePost=false&interval=1d&range=1mo"
    )"

    if [[ ${?} -ne 0 ]]; then
      cat "${HEADER_OUTPUT}" >/dev/stderr
      printf -- "%s\n" "${YAHOO_OUTPUT}" >/dev/stderr
      rm -f "${HEADER_OUTPUT}"
      return 1
    fi

    rm -f "${HEADER_OUTPUT}"

    PREVIOUS_PRICE="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].meta | .chartPreviousClose')"
    _stock_evolution

    printf -- "\n1mo %b%s%s%b\n" "${OUTPUT_COLOR}" "${EVOLUTION_SIGN}" "${EVOLUTION_PERCENT%00}%" "${RESET}"
    printf -- "%s" "${YAHOO_OUTPUT}" | jq -r '.chart.result[0].indicators.quote[0].open | join(",")' | spark
  fi

  printf -- "\nSource: https://finance.yahoo.com/quote/%s\n" "${1:-DDOG}"
}

date_in() {
  local TZ
  TZ="$(rg --files /usr/share/zoneinfo/ | sed 's|/usr/share/zoneinfo/||' | fzf --select-1 --query="${*:-New_York}")"

  printf -- "%b%s%b %b%s%b\n" "${BLUE}" "${TZ}" "${RESET}" "${YELLOW}" "$(TZ=${TZ} date '+%Y-%m-%d %H:%M:%S')" "${RESET}"
}

_fzf_complete_date_in() {
  FZF_COMPLETION_TRIGGER="" _fzf_complete --select-1 "${@}" < <(
    rg --files /usr/share/zoneinfo/ | sed 's|/usr/share/zoneinfo/||'
  )
}

[[ -n ${BASH} ]] && complete -F _fzf_complete_date_in -o default -o bashdefault date_in

temperature() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo powermetrics --samplers smc --sample-count 1 -i 1 | grep -i -E "temperature|fan"
  fi

  if command -v vcgencmd >/dev/null 2>&1; then
    echo "CPU $(($(</sys/class/thermal/thermal_zone0/temp) / 1000))c"
    vcgencmd measure_temp
  fi
}

if [[ ${OSTYPE} =~ ^darwin ]]; then
  system_state() {
    printf -- "%bThermal%b\n" "${BLUE}" "${RESET}"
    pmset -g therm
    printf -- "%bAC Power adapter%b\n" "${BLUE}" "${RESET}"
    pmset -g ac
    printf -- "%bBattery%b\n" "${BLUE}" "${RESET}"
    pmset -g batt
  }
fi

rainbow() {
  awk '
  BEGIN{
    s="          "; s=s s s s s s s s;
    for (colnum = 0; colnum<77; colnum++) {
      r = 255-(colnum*255/76);
      g = (colnum*510/76);
      b = (colnum*255/76);
      if (g>255) g = 510-g;
      printf "\033[48;2;%d;%d;%dm", r,g,b;
      printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
      printf "%s\033[0m", substr(s,colnum+1,1);
    }
    printf "\n";
  }'
}

order_66() {
  var_confirm "Erase all data"

  sudo --reset-timestamp echo "Erasing..."

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo networksetup -setdnsservers "Wi-Fi" Empty
    sudo networksetup -setsearchdomains "Wi-Fi" Empty

    for interface in "USB 10/100/1000 LAN" "Thunderbolt Ethernet Slot 0" "Thunderbolt Ethernet Slot 1"; do
      if [[ $(sudo networksetup -listnetworkserviceorder | grep -c -i "${interface}") -gt 0 ]]; then
        sudo networksetup -setdnsservers "${interface}" Empty
        sudo networksetup -setsearchdomains "${interface}" Empty
      fi
    done

    if [[ "$(type -t "notes_erase")" == "function" ]]; then
      notes_erase
    fi
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

  ssh_agent_stop
  gpg_agent_stop

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

if command -v vegeta >/dev/null 2>&1; then
  loadtest() {
    if [[ ${#} -lt 1 ]]; then
      var_red "Usage: loadtest URL"
      return 1
    fi

    local URL=${1}
    shift

    var_info "Attacking '${URL}' during 30 seconds..."
    printf -- "GET %s" "${URL}" | vegeta attack -duration=30s "${@}" | vegeta plot >vegeta.html && open vegeta.html
    sleep 5
    rm vegeta.html
  }
fi

if command -v systemctl >/dev/null 2>&1; then
  status() {
    sudo systemctl status "${@}"
  }

  restart() {
    sudo systemctl restart "${@}"
  }

  logs() {
    sudo journalctl -u "${@}"
  }
fi

aziz() {
  curl --disable --silent --show-error --location --max-time 30 --request POST "http://${HUE_API}/api/groups/${HUE_GROUP}" --data state=on --data method=PATCH >/dev/null
}

json() {
  jq --null-input --compact-output "${@}"
}
