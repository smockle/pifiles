#!/usr/bin/env bash
set -eo pipefail

copyto() {
  local PIHOST="${1}"

  # DDNS53
  echo "Checking for ddns53 configuration"
  if [ -d "${PWD}/ddns53" ]; then
    echo "Found, copying"
    ssh "${PIHOST}" 'mkdir -p "${HOME}/.ddns53"'
    scp -r "${PWD}/ddns53/." "${PIHOST}:~/.ddns53"
    echo "Done"
  else
    echo "Not found, skipping"
  fi
  echo ""

  # Homebridge
  echo "Checking for Homebridge configuration"
  if [ -d "${PWD}/homebridge" ]; then
    echo "Found, copying"
    ssh "${PIHOST}" 'mkdir -p "${HOME}/.homebridge"'
    scp -r "${PWD}/homebridge/." "${PIHOST}:~/.homebridge"
    echo "Done"
  else
    echo "Not found, skipping"
  fi
  echo ""
  unset PIHOST
}
copyto "$@"
unset copyto