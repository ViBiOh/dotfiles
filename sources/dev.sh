#!/usr/bin/env bash

alias dev='cd ${HOME}/code/'
alias work='test -e ${HOME}/dd/ && cd ${HOME}/dd/ || dev'
alias grep='grep --color=auto'
alias vi='vim'
alias fuck='sudo $(history -p \!\!)'

export EDITOR='vim'
export TERM='xterm-256color'

figmoji() {
  figlet -f banner "${1:-Hello}" | sed '$d' | sed -e"s|#|:${2:-wave}:|g" | sed -e's| |:empty:|g' | pbcopy
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
  local STOP_ON_SUCCESS=0
  if [[ ${1} == "-s" || ${1} == "--stop-on-success" ]]; then
    STOP_ON_SUCCESS=1
    shift
  fi

  if [[ ${#} -lt 1 ]]; then
    var_red "Usage: 'loop [-s|--stop-on-success] command' [interval?(default 60s)]"
    return 1
  fi

  while true; do
    eval "${1}"
    local EXIT_CODE=${?}

    if [[ ${STOP_ON_SUCCESS} -eq 1 && ${EXIT_CODE} -eq 0 ]]; then
      var_info "Command succeeded at $(date), stopping"
      return 0
    fi

    var_info "Ended at $(date), next in ${2:-60} seconds"
    sleep "${2:-60}"
  done
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
  local STOCK_TICKER="${1:-DDOG}"

  _stock_fetch() {
    local HEADER_OUTPUT
    HEADER_OUTPUT=$(mktemp)

    local FETCH_OUTPUT
    if ! FETCH_OUTPUT="$(
      curl \
        --disable \
        --silent \
        --show-error \
        --location \
        --max-time 10 \
        --header "User-Agent: Mozilla/5.0" \
        --dump-header "${HEADER_OUTPUT}" \
        --fail-with-body \
        "https://query1.finance.yahoo.com/v8/finance/chart/${1}?${2}"
    )"; then
      cat "${HEADER_OUTPUT}" >/dev/stderr
      printf -- "%s\n" "${FETCH_OUTPUT}" >/dev/stderr
      rm -f "${HEADER_OUTPUT}"
      return 1
    fi

    rm -f "${HEADER_OUTPUT}"
    printf -- "%s" "${FETCH_OUTPUT}"
  }

  _stock_meta() {
    printf -- "%s" "${1}" | jq --raw-output ".chart.result[0].meta | .${2}"
  }

  _stock_evolution() {
    local _EVOLUTION_PREVIOUS="${1}"
    local _EVOLUTION_CURRENT="${2}"

    if [[ ${_EVOLUTION_PREVIOUS} == "0.0" ]]; then
      _EVOLUTION_PREVIOUS="${_EVOLUTION_CURRENT}"
    fi

    local EVOLUTION_PERCENT
    EVOLUTION_PERCENT="$(printf -- "scale = 4; 100 * ((%s / %s) - 1)\n" "${_EVOLUTION_CURRENT}" "${_EVOLUTION_PREVIOUS}" | bc)"

    if [[ ${EVOLUTION_PERCENT} == 0 ]]; then
      return
    fi

    local _EVOLUTION_COLOR="${GREEN}"
    local _EVOLUTION_SIGN="↗"

    if [[ ${EVOLUTION_PERCENT} =~ ^- ]]; then
      _EVOLUTION_COLOR="${RED}"
      _EVOLUTION_SIGN="↘"
      EVOLUTION_PERCENT="${EVOLUTION_PERCENT#-}"
    fi

    printf " %b%s%s%b" "${_EVOLUTION_COLOR}" "${_EVOLUTION_SIGN}" "${EVOLUTION_PERCENT%00}%" "${RESET}"
  }

  _stock_quote() {
    printf -- "%b%s%b %s %s" "${YELLOW}" "${2}" "${RESET}" "$(_stock_meta "${1}" "regularMarketPrice")" "$(_stock_meta "${1}" "currency")"
    _stock_evolution "$(_stock_meta "${1}" "previousClose")" "$(_stock_meta "${1}" "regularMarketPrice")"
  }

  local YAHOO_OUTPUT
  if ! YAHOO_OUTPUT="$(_stock_fetch "${STOCK_TICKER}" "includePrePost=true&interval=1h&range=1d")"; then
    return 1
  fi

  local CURRENT_PRICE
  CURRENT_PRICE="$(_stock_meta "${YAHOO_OUTPUT}" "regularMarketPrice")"

  _stock_quote "${YAHOO_OUTPUT}" "$(_stock_meta "${YAHOO_OUTPUT}" "symbol")"

  local REGULAR_START
  REGULAR_START="$(_stock_meta "${YAHOO_OUTPUT}" "currentTradingPeriod.regular.start")"

  local REGULAR_END
  REGULAR_END="$(_stock_meta "${YAHOO_OUTPUT}" "currentTradingPeriod.regular.end")"

  local CURRENT_TIMESTAMP
  CURRENT_TIMESTAMP="$(date +%s)"

  local PREMARKET_PRICE
  PREMARKET_PRICE="$(printf -- "%s" "${YAHOO_OUTPUT}" | jq --raw-output '.chart.result[0].indicators.quote[0].open[-1]')"

  if [[ ${CURRENT_TIMESTAMP} -lt ${REGULAR_START} ]] || [[ ${CURRENT_TIMESTAMP} -gt ${REGULAR_END} ]] && [[ ${PREMARKET_PRICE:-} != "null" ]]; then
    printf -- " | Pre %s" "${PREMARKET_PRICE}"
    _stock_evolution "${CURRENT_PRICE}" "${PREMARKET_PRICE}"
  fi

  printf -- "\n"

  if [[ $(_stock_meta "${YAHOO_OUTPUT}" "currency") == "USD" ]]; then
    local CURRENCY_OUTPUT
    if ! CURRENCY_OUTPUT="$(_stock_fetch "USDEUR=X" "includePrePost=false&interval=1h&range=1d")"; then
      return 1
    fi

    _stock_quote "${CURRENCY_OUTPUT}" "USD -> EUR"
    printf -- "\n"
  fi

  if command -v spark >/dev/null 2>&1; then
    local MONTH_OUTPUT
    if ! MONTH_OUTPUT="$(_stock_fetch "${STOCK_TICKER}" "includePrePost=false&interval=1d&range=1mo")"; then
      return 1
    fi

    printf -- "\n1mo"
    _stock_evolution "$(_stock_meta "${MONTH_OUTPUT}" "chartPreviousClose")" "${CURRENT_PRICE}"
    printf -- "\n"

    printf -- "%s" "${MONTH_OUTPUT}" | jq --raw-output '.chart.result[0].indicators.quote[0].open | join(",")' | spark
  fi

  printf -- "\nSource: https://finance.yahoo.com/quote/%s\n" "${STOCK_TICKER}"
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

if command -v vegeta >/dev/null 2>&1; then
  loadtest() {
    if [[ ${#} -lt 1 ]]; then
      var_red "Usage: loadtest URL"
      return 1
    fi

    local URL=${1}
    shift

    var_info "Attacking '${URL}' during 30 seconds..."
    printf -- "GET %s" "${URL}" | vegeta attack -duration=30s "${@}" | vegeta plot >vegeta.html && xdg-open vegeta.html
    sleep 5
    rm vegeta.html
  }
fi

if command -v systemctl >/dev/null 2>&1; then
  status() {
    sudo systemctl status "${@}"
  }

  logs() {
    sudo journalctl -f -u "${@}"
  }

  restart() {
    sudo systemctl restart "${@}"
    logs "${@}"
  }
fi

aziz() {
  local HUE_CREDENTIALS
  HUE_CREDENTIALS="$(pass_get "infra/hue" "login"):$(pass "infra/hue" | head -1)"

  # Escape backslash then double quote for curl's config parser
  HUE_CREDENTIALS="${HUE_CREDENTIALS//\\/\\\\}"
  HUE_CREDENTIALS="${HUE_CREDENTIALS//\"/\\\"}"

  curl --disable --silent --show-error --location --max-time 30 --request POST \
    --config <(printf -- 'user = "%s"\n' "${HUE_CREDENTIALS}") \
    "${HUE_API}/api/groups/${HUE_GROUP}" --data state=on --data method=PATCH >/dev/null
}

if [[ ${OSTYPE} =~ ^darwin ]]; then
  slack2md() {
    if ! command -v pandoc >/dev/null 2>&1; then
      var_red "pandoc is required"
      return 1
    fi

    local SELECTION_SCRIPT
    SELECTION_SCRIPT="(function() {
      var sel = window.getSelection();
      var box = document.createElement('div');
      for (var i = 0; i < sel.rangeCount; i++) {
        box.appendChild(sel.getRangeAt(i).cloneContents());
      }
      box.querySelectorAll('.c-mrkdwn__br').forEach(function(node) {
        node.replaceWith(document.createElement('br'), document.createElement('br'));
      });
      box.querySelectorAll('img[data-stringify-emoji]').forEach(function(node) {
        node.replaceWith(document.createTextNode(node.alt));
      });
      return box.innerHTML;
    })()"

    local SELECTION_HTML
    SELECTION_HTML="$(osascript \
      -e 'on run argv' \
      -e 'tell application "Google Chrome" to execute active tab of front window javascript (item 1 of argv)' \
      -e 'end run' \
      "${SELECTION_SCRIPT}")"

    if [[ -z ${SELECTION_HTML} ]]; then
      var_red "Nothing selected in the active Chrome tab (Chrome: View > Developer > Allow JavaScript from Apple Events)"
      return 1
    fi

    local MARKDOWN
    MARKDOWN="$(printf -- "%s" "${SELECTION_HTML}" | pandoc --from html --to gfm-raw_html --wrap=none | sed 's/\\$//')"

    printf -- "%s" "${MARKDOWN}" | pbcopy
    printf -- "%s\n" "${MARKDOWN}"
    var_info "Markdown copied to the clipboard"
  }
fi

json() {
  jq --null-input --compact-output "${@}"
}
