#!/usr/bin/env bash

OUTPUT_JSON="false"

OPTIND=0
while getopts ":j" option; do
  case "${option}" in
  j)
    OUTPUT_JSON="true"
    ;;
  \?)
    printf -- "option -%s is invalid\n" "${OPTARG}" 1>&2
    return 2
    ;;
  esac
done

shift $((OPTIND - 1))

if [[ ${OUTPUT_JSON:-} == "true" ]]; then
  jq --null-input --compact-output --arg value "$(pass show "dev/ansible")" '{pass: $value}'
else
  pass show "dev/ansible"
fi
