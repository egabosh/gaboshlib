#!/bin/bash

function g_check_tor {
  local torrestart=false

  # check socks5
  local curl="curl --connect-timeout 7 --socks5-hostname $g_tor_host:$g_tor_socks5_port https://check.torproject.org/api/ip"
  $curl >${g_tmp}/check.torproject.org-socks.json || ( sleep 7 ; $curl >${g_tmp}/check.torproject.org-socks.json 2>${g_tmp}/curl.err)
  rc=$?
  if ! cat $g_tmp/check.torproject.org-socks.json | jq -a .IsTor | grep -q '^true$'
  then
    g_echo_error "Tor over socks5 not working. curl return code: $rc
$curl
$(cat ${g_tmp}/curl.err)
$(cat ${g_tmp}/check.torproject.org-socks.json)"
    torrestart=true
  fi

  # Check proxy
  curl="curl -s --connect-timeout 7 --proxy $g_tor_host:$g_tor_proxy_port https://check.torproject.org/api/ip"
  $curl >${g_tmp}/check.torproject.org-proxy.json || ( sleep 7 ; $curl >${g_tmp}/check.torproject.org-proxy.json 2>${g_tmp}/curl.err)
  if ! cat ${g_tmp}/check.torproject.org-proxy.json | jq -a .IsTor | grep -q '^true$'
  then
    g_echo_error "Tor proxy not working. curl return code: $rc
$curl
$(cat ${g_tmp}/curl.err)
$(cat ${g_tmp}/check.torproject.org-proxy.json)"
    #torrestart=true
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

