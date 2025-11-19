#!/bin/bash

function g_check_internet {
  local testip
  for testip in $g_testips
  do
    if ping -W1 -c1 ${testip} >/dev/null 2>&1
    then
      g_echo "Internet connection OK (testip: $testip)"
      return 0
    fi
  done
  local gw=$(ip route | awk '/default/ {print $3}')
  local gw6=$(ip route | awk '/default/ {print $3}')
  g_echo_error "No Internet connection? ping $testip failed! Default gateway IPv4: $gw ; IPv6: $gw6"
  return 1
}
