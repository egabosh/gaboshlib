#!/bin/bash

function g_check_tor {
  local torrestart=false

  # check socks5
  if ! curl -s --connect-timeout 7 --socks5-hostname $g_tor_host:$g_tor_socks5_port https://check.torproject.org/api/ip | jq -a .IsTor | grep -q '^true$'
  then
    g_echo_error "Tor over socks5 not working"
    torrestart=true
  fi

  # Check proxy
  if ! curl -s --connect-timeout 7 --proxy $g_tor_host:$g_tor_proxy_port https://check.torproject.org/api/ip | jq -a .IsTor | grep -q '^true$'
  then
    g_echo_error "Tor proxy not working"
    torrestart=true
  fi

  # check for restart
  if [[ $torrestart = "true" ]]
  then
    g_echo_warn "Restarting Tor"
    systemctl restart tor.service
    return 1
  fi

  g_echo "Tor works!" 
  return 0
}

