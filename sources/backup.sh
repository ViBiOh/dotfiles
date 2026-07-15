#!/usr/bin/env bash

backup() {
  local BACKUP_PASSPHRASE="${1:-$(pass_get "infra/backup" "aes")}"

  tar -czf - . | pv | gpg --symmetric --cipher-algo AES256 --batch --passphrase-fd 3 3< <(printf -- '%s' "${BACKUP_PASSPHRASE}") >"$(basename "$(pwd)").tar.gz.gpg"
}

backup_upload() {
  MC_UPLOAD_MULTIPART_SIZE=104857600 mc mv --storage-class ONEZONE_IA "${1:-$(basename "$(pwd)")}.tar.gz.gpg" "scw/fibr/"
}

backup_dir() {
  (
    cd "${1-}" || return
    backup ""
  )
}

backup_all() {
  tmux_batch -a backup_dir 'find . -mindepth 1 -maxdepth 1 -type d -not -path "./.*" -print0'
}

backup_restore() {
  local BASE_FILENAME="${1:-backup}"
  local BACKUP_PASSPHRASE="${2:-$(pass_get "infra/backup" "aes")}"

  mkdir "${BASE_FILENAME}"
  gpg --decrypt --batch --passphrase-fd 3 "${BASE_FILENAME}.tar.gz.gpg" 3< <(printf -- '%s' "${BACKUP_PASSPHRASE}") | pv | tar -xz -C "${BASE_FILENAME}" -
}

backup_clean() {
  mc rm "scw/fibr/" --incomplete --recursive --force
}

backup_rclone() {
  local REMOTE_NAME
  REMOTE_NAME="$(rclone config dump --password-command 'pass infra/rclone' | jq -r 'keys[]' | fzf --height=20 --ansi --reverse --prompt "Remote: ")"

  if [[ -z ${REMOTE_NAME} ]]; then
    return
  fi

  if var_confirm "Backup current folder to ${REMOTE_NAME}"; then
    rclone sync \
      --password-command 'pass infra/rclone' \
      --progress \
      --multi-thread-streams "8" \
      --delete-excluded \
      --exclude ".stfolder/**" \
      --exclude ".fibr/*/**" \
      "." "${REMOTE_NAME}:"
  fi
}
