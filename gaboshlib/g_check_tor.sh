#!/bin/bash

function g_check_tor {
  local torrestart=false
  local curl_opts

  for curl_opts in "--socks5-hostname $g_tor_host:$g_tor_socks5_port" "--proxy $g_tor_host:$g_tor_proxy_port"
  do
    # check socks5
    curl="curl --retry 3 --retry-delay 5 --retry-connrefused --connect-timeout 5 $curl_opts https://check.torproject.org/api/ip"
    $curl >${g_tmp}/check.torproject.org.json 2>${g_tmp}/curl.err
    rc=$?
    if ! cat $g_tmp/check.torproject.org.json | jq -a .IsTor | grep -q '^true$'
    then
      g_echo_error "Tor ($curl_opts) not working. curl return code: $rc
$curl
$(cat ${g_tmp}/curl.err)
$(cat ${g_tmp}/check.torproject.org.json)"
      torrestart=true
    else
      g_echo "Tor working ($curl_opts): $(cat ${g_tmp}/check.torproject.org.json)"
    fi
    rm ${g_tmp}/check.torproject.org.json
  done

  # check for restart
  if [[ $torrestart = "true" ]]
  then
    g_echo_warn "Restarting Tor"
    systemctl restart tor.service
    return 1
  fi

  return 0
}

