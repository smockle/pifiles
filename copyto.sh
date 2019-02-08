#!/usr/bin/env bash
set -eo pipefail

copyto() {
  local PIHOST="${1}"

  # DDNS53
  echo "Checking for a ddns53 configuration file in 'ddns53/config'"
  if [ -f "${PWD}/ddns53/config" ]; then
    echo "Found, copying"
    scp "${PWD}/ddns53/config" "${PIHOST}:/tmp/ddns53.config"
    ssh "${PIHOST}" 'mkdir -p "${HOME}/.ddns53"'
    ssh "${PIHOST}" 'mv -f /tmp/ddns53.config "${HOME}/.ddns53/config"'
    echo "Done"
  else
    echo "Not found, skipping"
  fi
  echo ""

  # Homebridge
  echo "Checking for a Homebridge configuration file in 'homebridge/config.json'"
  if [ -f "${PWD}/homebridge/config.json" ]; then
    echo "Found, copying"
    scp "${PWD}/homebridge/config.json" "${PIHOST}:/tmp/homebridge.config.json"
    ssh "${PIHOST}" 'mkdir -p "${HOME}/.homebridge"'
    ssh "${PIHOST}" 'mv -f /tmp/homebridge.config.json "${HOME}/.homebridge/config.json"'
    echo "Done"
  else
    echo "Not found, skipping"
  fi

  unset PIHOST
}
copyto "$@"
unset copyto