#!/usr/bin/env zsh

bluetooth-reconnect() {
  local MAC_ADDRESS=$1
  shift 1
  if [ bluetoothctl info "${MAC_ADDRESS}" | grep -Fq 'Connected: no' ]; then
    echo -e "disconnect\nconnect ${MAC_ADDRESS}\nexit" | bluetoothctl
  fi
  unset MAC_ADDRESS
}