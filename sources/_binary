#!/usr/bin/env bash

archive_to_binary() {
  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: archive_to_binary ARCHIVE_URL BINARY_PATH [BINARY_DESTINATION=${HOME}/opt/bin/]"
    return 1
  fi

  local ARCHIVE_URL="${1}"
  shift
  local BINARY_PATH="${1}"
  shift
  local BINARY_DESTINATION="${1:-${HOME}/opt/bin}"
  shift || true

  local ARCHIVE_FILENAME
  local ARCHIVE_EXTENSION
  if [[ ${ARCHIVE_URL} =~ .*\/(.*)\.(tar\.[g|x]z|zip) ]]; then
    ARCHIVE_FILENAME="${BASH_REMATCH[1]}"
    ARCHIVE_EXTENSION="${BASH_REMATCH[2]}"
  else
    var_error "archive_to_binary: unable to extract archive filename and extension from ${ARCHIVE_URL}"
    return 1
  fi

  local TEMP_FOLDER
  TEMP_FOLDER="$(mktemp -d)"

  local ARCHIVE_PATH="${TEMP_FOLDER}/${ARCHIVE_FILENAME}.${ARCHIVE_EXTENSION}"

  curl --disable --silent --show-error --location --max-time 300 --output "${ARCHIVE_PATH}" -- "${ARCHIVE_URL}"
  (
    cd "${TEMP_FOLDER}" || false
    mkdir -p "${ARCHIVE_FILENAME}"

    if [[ ${ARCHIVE_EXTENSION} == "tar.gz" ]]; then
      tar -xzf "${ARCHIVE_PATH}" -C "${ARCHIVE_FILENAME}"
    elif [[ ${ARCHIVE_EXTENSION} == "tar.xz" ]]; then
      tar -xf "${ARCHIVE_PATH}" -C "${ARCHIVE_FILENAME}"
    elif [[ ${ARCHIVE_EXTENSION} == "zip" ]]; then
      unzip "${ARCHIVE_PATH}" -d "${ARCHIVE_FILENAME}"
    fi

    mv "${ARCHIVE_FILENAME}/${BINARY_PATH}" "${BINARY_DESTINATION}"

    if [[ -d ${BINARY_DESTINATION} ]]; then
      chmod +x "${BINARY_DESTINATION}/$(basename "${BINARY_PATH}")"
    else
      chmod +x "${BINARY_DESTINATION}"
    fi
  )

  rm -rf "${ARCHIVE_FILENAME}" "${TEMP_FOLDER}"
}

curl_to_binary() {
  if [[ ${#} -lt 2 ]]; then
    var_red "Usage: curl_to_binary BINARY_URL BINARY_NAME [BINARY_DESTINATION=${HOME}/opt/bin]"
    return 1
  fi

  local BINARY_URL="${1}"
  shift
  local BINARY_NAME="${1}"
  shift
  local BINARY_DESTINATION="${1:-${HOME}/opt/bin}"
  shift || true

  curl --disable --silent --show-error --location --max-time 300 --output "${BINARY_DESTINATION}/${BINARY_NAME}" -- "${BINARY_URL}"
  chmod +x "${BINARY_DESTINATION}/${BINARY_NAME}"
}

normalized_os() {
  local OS_NAME
  OS_NAME="$(uname -s | tr "[:upper:]" "[:lower:]")"

  local MACOS_VALUE="${1-}"
  shift || true

  if [[ ${OS_NAME} == "darwin" ]] && [[ -n ${MACOS_VALUE} ]]; then
    OS_NAME="${MACOS_VALUE}"
  fi

  printf "%s" "${OS_NAME}"
}

normalized_arch() {
  local ARCH
  ARCH="$(uname -m | tr "[:upper:]" "[:lower:]")"

  local X86_VALUE="${1-}"
  shift || true

  local ARM_VALUE="${1-}"
  shift || true

  local ARM64_VALUE="${1-}"
  shift || true

  if [[ ${ARCH} == "arm64" ]]; then
    ARCH="aarch64"
  fi

  if [[ ${ARCH} == "x86_64" ]] && [[ -n ${X86_VALUE} ]]; then
    ARCH="${X86_VALUE}"
  elif [[ ${ARCH} =~ ^armv ]] && [[ -n ${ARM_VALUE} ]]; then
    ARCH="${ARM_VALUE}"
  elif [[ ${ARCH} == "aarch64" ]] && [[ -n ${ARM64_VALUE} ]]; then
    ARCH="${ARM64_VALUE}"
  fi

  printf "%s" "${ARCH}"
}
