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
  if command -v unbound >/dev/null 2>&1; then
    if [[ ${OSTYPE} =~ ^darwin ]] && command -v brew >/dev/null 2>&1; then
      sudo brew services restart "unbound"
    elif command -v systemctl >/dev/null 2>&1; then
      sudo systemctl enable "unbound.service"
      sudo systemctl restart "unbound.service"
    fi
  fi

  if [[ ${OSTYPE} =~ ^darwin ]]; then
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
  elif command -v systemctl >/dev/null 2>&1 && [[ $(systemctl list-units systemd-resolve* | wc -l) -gt 2 ]]; then
    sudo systemd-resolve --flush-caches
  fi
}

dns_set() {
  if ! [[ ${OSTYPE} =~ ^darwin ]]; then
    return
  fi

  while IFS= read -r interface; do
    sudo networksetup -setdnsservers "${interface#\*}" "${@:-}"
    sudo networksetup -setsearchdomains "${interface#\*}" "local"
  done <<<"$(sudo networksetup -listallnetworkservices | tail -n+2)"

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
      alb.reddit.com
      external-preview.redd.it
      gateway.reddit.com
      gql.reddit.com
      oauth.reddit.com
      www.reddit.com
      styles.redditmedia.com
      thumbs.redditmedia.com
      www.redditmedia.com
      www.redditstatic.com
      reddit.map.fastly.net
  "

  websites["linkedin"]="
    www.linkedin.com
    media.licdn.com
    static.licdn.com
    dms.licdn.com
  "

  websites["linkedin_blog"]="
    content.linkedin.com
    engineering.linkedin.com
  "

  websites["aws"]="
    analytics.console.aws.a2z.com
    awstrack.me
  "

  websites["datadog"]="
    www.datadoghq-browser-agent.com
    browser-intake-datadoghq.eu
    live.logs.datadoghq.com
  "

  websites["mtv"]="
    pagead2.googlesyndication.com
    securepubads.g.doubleclick.net
    sdk.iad-01.braze.com
    iad-01.braze.com
  "

  websites["twitter"]="
    api.twitter.com
    www.twitter.com
    x.com
    t.co
    abs.twimg.com
    pbs.twimg.com
  "

  websites["instagram"]='
    www.instagram.com
    static.cdninstagram.com
    scontent-cdg[0-9]-[0-9]\.cdninstagram.com
  '

  websites["gtm"]="
    www.googletagmanager.com
  "

  websites["laposte"]="
    t.notif-colissimo-laposte.info
  "

  local WEBSITE
  WEBSITE="$(printf -- "%s\n" "${!websites[@]}" | fzf --select-1 --query="${1-}" --exit-0)"

  if [[ -z ${WEBSITE} ]]; then
    return 1
  fi

  dns_unblock ${websites[${WEBSITE}]}
}

dns_unblock() {
  local GREP_PIPELINE=()
  local current

  for entry in "${@}"; do
    current="${entry}"

    while [[ ${current} == *.* ]]; do
      GREP_PIPELINE+=("--regexp" "^local-zone: \"${current}\" refuse")

      if [[ ${current} =~ \\ ]]; then
        break
      fi

      current="${current#*.}"
    done
  done

  local UNBOUND_BLOCKLIST
  UNBOUND_BLOCKLIST=$(mktemp)

  grep --invert-match "${GREP_PIPELINE[@]}" "${HOME}/.unbound-blocklist" >"${UNBOUND_BLOCKLIST}"

  mv "${UNBOUND_BLOCKLIST}" "${HOME}/.unbound-blocklist"

  dns_flush
}
