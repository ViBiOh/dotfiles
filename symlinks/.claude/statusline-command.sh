#!/usr/bin/env bash

input=$(cat)

PCT=$(printf "%s" "${input}" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""

[[ $FILLED -gt 0 ]] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[[ $EMPTY -gt 0 ]] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

printf "[%s] %s %s%%" "$(printf "%s" "${input}" | jq -r '.model.display_name')" "${BAR}" "${PCT}"
