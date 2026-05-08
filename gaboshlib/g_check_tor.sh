#!/bin/bash

function g_check_tor {
  local curl_opts

  g_check_tor_transparent_proxy && return 99

  for curl_opts in "--socks5-hostname $g_tor_host:$g_tor_socks5_port" "--proxy $g_tor_host:$g_tor_proxy_port"
  do
    try=1
    
    # check socks5
    curl="curl --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 5 $curl_opts https://check.torproject.org/api/ip"
    $curl >${g_tmp}/check.torproject.org.json 2>${g_tmp}/curl.err
    rc=$?
    if ! cat $g_tmp/check.torproject.org.json | jq -a .IsTor | grep -q '^true$'
    then
      g_echo_error "Tor ($curl_opts) not working. curl return code: $rc
$curl
$(cat ${g_tmp}/curl.err)
$(cat ${g_tmp}/check.torproject.org.json)"
      return 1
    else
      g_echo "Tor working ($curl_opts): $(cat ${g_tmp}/check.torproject.org.json)"
      # stop local tor if we do not use it on localhost
      [[ $g_tor_host != "127.0.0.1" ]] && systemctl stop tor.service
      return 0
    fi
  done
}

