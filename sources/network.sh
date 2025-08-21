#!/usr/bin/env bash

open_ports() {
  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo lsof -PniTCP -sTCP:LISTEN
  elif command -v ss >/dev/null 2>&1; then
    sudo ss -plant
  elif command -v netstat >/dev/null 2>&1; then
    sudo netstat -pluton
  fi
}

default_route() {
  route -n get default
}

dns_flush() {
  if command -v unbound-control >/dev/null 2>&1; then
    if [[ ${UNBOUND_CONTROL-} == "no" ]]; then
      sudo systemctl enable "unbound.service"
      sudo systemctl restart "unbound.service"
    else
      local UNBOUND_CONF_FOLDER="${BREW_PREFIX-}/etc/unbound"
      local UNBOUND_DNSSEC_CERT="${UNBOUND_CONF_FOLDER}/root.key"
      local UNBOUND_CONF_FILE="${UNBOUND_CONF_FOLDER}/unbound.conf"

      sudo unbound-anchor -a "${UNBOUND_DNSSEC_CERT}"
      sudo unbound-control -c "${UNBOUND_CONF_FILE}" -q reload 2>/dev/null || true
      sudo unbound-control -c "${UNBOUND_CONF_FILE}" -q stop 2>/dev/null || true

      printf -- "Waiting 1 second before starting again...\n"
      sleep 1

      sudo unbound-control -c "${UNBOUND_CONF_FILE}" -q start
    fi
  fi

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
  else
    if [[ $(systemctl list-units systemd-resolve* | wc -l) -gt 2 ]]; then
      sudo systemd-resolve --flush-caches
    fi
  fi
}

dns_set() {
  if ! [[ ${OSTYPE} =~ ^darwin ]]; then
    return
  fi

  for interface in "Wi-Fi" "USB 10/100/1000 LAN" "Thunderbolt Ethernet Slot 0" "Thunderbolt Ethernet Slot 1"; do
    if [[ $(sudo networksetup -listnetworkserviceorder | grep -c -i "${interface}") -gt 0 ]]; then
      sudo networksetup -setdnsservers "${interface}" "${@:-}"
      sudo networksetup -setsearchdomains "${interface}" "local"
    fi
  done

  dns_flush
}

dns_block() {
  cat \
    <(curl --disable --silent --show-error --location --max-time 30 "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/${BLOCKED_HOSTS:-fakenews-gambling-porn-social}/hosts") \
    <(curl --disable --silent --show-error --location --max-time 30 "https://someonewhocares.org/hosts/zero/hosts") |
    grep --extended-regexp --invert-match '^$' |
    grep --extended-regexp --invert-match '^\s*#' |
    grep --extended-regexp '^(0.0.0.0|127.0.0.1|255.255.255.255|::1|fe00::|ff02::)' |
    tr -s '[:blank:]' ' ' |
    tr '[:upper:]' '[:lower:]' |
    sort --unique |
    grep --extended-regexp '^0.0.0.0 ' |
    awk '{print "local-zone: \""$2"\" refuse"}' |
    sort --unique >"${1:-${HOME}/.unbound-blocklist}"
}

dns_allow() {
  declare -A websites

  websites["reddit"]="
      preview.redd.it
      v.redd.it
      redd.it
      alb.reddit.com
      external-preview.redd.it
      gateway.reddit.com
      gql.reddit.com
      oauth.reddit.com
      www.reddit.com
      reddit.com
      styles.redditmedia.com
      thumbs.redditmedia.com
      www.redditmedia.com
      redditmedia.com
      www.redditstatic.com
      reddit.map.fastly.net
  "

  websites["linkedin"]="
    www.linkedin.com
    linkedin.com
    media.licdn.com
    static.licdn.com
    dms.licdn.com
  "

  websites["linkedin_blog"]="
    content.linkedin.com
    engineering.linkedin.com
    linkedin.com
  "

  websites["aws"]="analytics.console.aws.a2z.com"

  websites["datadog"]="
    www.datadoghq-browser-agent.com
    browser-intake-datadoghq.eu
    live.logs.datadoghq.com
    logs.datadoghq.com
  "

  websites["mtv"]="
    googlesyndication.com
    pagead2.googlesyndication.com
    securepubads.g.doubleclick.net
    g.doubleclick.net
    doubleclick.net
    sdk.iad-01.braze.com
    iad-01.braze.com
    braze.com
  "

  websites["twitter"]="
    api.twitter.com
    www.twitter.com
    twitter.com
    x.com
    t.co
    abs.twimg.com
    pbs.twimg.com
    twimg.com
  "

  websites["instragram"]="
    www.instragram.com
    instragram.com
    static.cdninstagram.com
    scontent-.{3,4}(-.)?.cdninstagram.com
  "

  websites["gtm"]="
    www.googletagmanager.com
    googletagmanager.com
  "

  websites["laposte"]="
    t.notif-colissimo-laposte.info
  "

  local WEBSITE
  WEBSITE="$(printf -- "%s\n" "${!websites[@]}" | fzf --select-1 --query="${1-}" --exit-0)"

  if [[ -z ${WEBSITE} ]]; then
    return 1
  fi

  local GREP_PIPELINE=()

  dns_unblock ${websites[${WEBSITE}]}
}

dns_unblock() {
  local GREP_PIPELINE=()

  for entry in "${@}"; do
    GREP_PIPELINE+=("--regexp" "\"${entry}\"")
  done

  local UNBOUND_BLOCKLIST
  UNBOUND_BLOCKLIST=$(mktemp)

  grep --invert-match "${GREP_PIPELINE[@]}" "${HOME}/.unbound-blocklist" >"${UNBOUND_BLOCKLIST}"

  mv "${UNBOUND_BLOCKLIST}" "${HOME}/.unbound-blocklist"

  dns_flush
}
