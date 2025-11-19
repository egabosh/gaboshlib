#!/bin/bash

function g_check_fix_dns_stack {
  g_check_internet || return 1
  g_check_dns_stack || g_restart_dns_stack
}

function g_check_dns_stack  {
  local testip
  resolvectl flush-caches >/dev/null 2>&1
  nscd -i hosts >/dev/null 2>&1
  for testip in $g_testips
  do
    if host -W1 $testip >>"${g_tmp}/g_check_dns_stack_output" 2>&1
    then
      g_echo "Internet DNS connection OK (testip: $testip)"
      return 0
    fi
  done
  g_echo_warn "DNS Resoulution seems broken $(cat "${g_tmp}/g_check_dns_stack_output")"
  return 1
}

function g_restart_dns_stack {
  local service
  for service in tor dnscrypt-proxy systemd-resolved nscd
  do
    g_echo_warn "DNS-Problems - restarting  $service"
    systemctl status $service.service 2>/dev/null | grep -q 'Active: active (running)' || continuea
    systemctl restart $service.service
    sleep 5
  done
}

