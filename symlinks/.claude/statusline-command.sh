#!/usr/bin/env bash

input=$(cat)

PCT=$(printf "%s" "${input}" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""

[[ $FILLED -gt 0 ]] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[[ $EMPTY -gt 0 ]] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

printf "\033[34m%s\033[0m %s \033[33m%s\033[0m" \
  "$(printf "%s" "${input}" | jq -r '.model.display_name')" \
  "${BAR}" \
  "$(jq -r '.cost.total_cost_usd // 0 | . * 1000 | round | . / 1000 | tostring' | awk '{printf "$%.3f", $1}')"
