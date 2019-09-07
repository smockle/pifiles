#!/usr/bin/env zsh

bluetooth-reconnect() {
  let "ITERATIONS = ${1} - 1"
  shift 1
  local MAC_ADDRESS="${1}"
  shift 1
  if [ "${ITERATIONS}" -eq "0" ]; then
    echo "Failed to connect"
    exit 1
  fi
  if ! bluetoothctl info "${MAC_ADDRESS}" &>/dev/null; then
    echo "Invalid address"
    exit 1
  fi 
  if $(bluetoothctl info "${MAC_ADDRESS}" | grep -Fq 'Connected: no'); then
    echo "Connecting (iterations: ${ITERATIONS})"
    echo -e "disconnect\nconnect ${MAC_ADDRESS}\nexit" | bluetoothctl &>/dev/null
    sleep 1
    bluetooth-reconnect "${ITERATIONS}" "${MAC_ADDRESS}"
  else
    echo "Connected"
  fi
  unset MAC_ADDRESS
}

bluetooth-reconnect 6 "${@}"
