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
  if [ -z "$gw" ] && [ -z "$gw6" ]
  then
    g_echo_warn "No gateway found - restart complete networking with systemctl restart networking.service"
    systemctl restart networking.service >/dev/null 2>&1
  fi
  return 1
}
