#!/usr/bin/env bash

backup() {
  tar -czf - . | pv | gpg --symmetric --cipher-algo AES256 --batch --passphrase "${1:-$(pass_get "infra/backup" "aes")}" >"$(basename "$(pwd)").tar.gz.gpg"
}

backup_upload() {
  MC_UPLOAD_MULTIPART_SIZE=104857600 mc mv --storage-class ONEZONE_IA "${1:-$(basename "$(pwd)")}.tar.gz.gpg" "scw/fibr/"
}

backup_dir() {
  (
    cd "${1-}" || return
    backup ""
    backup_upload ""
  )
}

backup_all() {
  tmux_batch -a backup_dir 'find . -mindepth 1 -maxdepth 1 -type d -not -path "./.*" -print0'
}

backup_restore() {
  local BASE_FILENAME="${1:-backup}"

  mkdir "${BASE_FILENAME}"
  gpg --decrypt --batch --passphrase "${2:-$(pass_get "infra/backup" "aes")}" "${BASE_FILENAME}.tar.gz.gpg" | pv | tar -xz -C "${BASE_FILENAME}" -
}

backup_clean() {
  mc rm "scw/fibr/" --incomplete --recursive --force
}
