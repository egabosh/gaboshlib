#!/bin/bash
g_check_tor_transparent_proxy() {
  local g_domain="check.tor-project.org"
  local g_hosts_file="/etc/hosts"
  local g_entry_regex="check\.tor-project\.org"
  local g_dns_servers=()

  # Collect DNS servers from all network interfaces via resolvectl
  for g_iface in /sys/class/net/*/
  do
    g_iface=$(basename "$g_iface")

    if [[ "$g_iface" = "lo" ]]
    then
      continue
    fi

    while IFS= read -r g_server
    do
      if [[ -n "$g_server" ]]
      then
        g_dns_servers+=("$g_server")
      fi
    done < <(
      resolvectl dns "$g_iface" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
    )
  done

  # Remove duplicates
  g_dns_servers=($(printf '%s\n' "${g_dns_servers[@]}" | awk '!seen[$0]++'))

  if [[ ${#g_dns_servers[@]} -eq 0 ]]
  then
    g_echo_error "No DNS servers found" >&2
    return 2
  fi

  local g_resolved_ip=""

  # Try each DNS server until resolution succeeds
  for g_dns in "${g_dns_servers[@]}"
  do
    g_result=$(host "$g_domain" "$g_dns" 2>/dev/null | grep ' has address ' | awk '{print $NF}' | head -1)

    if [[ -n "$g_result" ]]
    then
      g_resolved_ip="$g_result"
      break
    fi
  done

  if [[ -z "$g_resolved_ip" ]]
  then
    g_echo_error "Could not resolve $g_domain via any DNS server" >&2
    return 3
  fi

  local g_tmpfile="${g_tmp}/g_check_tor_transparent_proxy-hosts.tmp"

  # Update or append entry in /etc/hosts
  if grep -qE "$g_entry_regex" "$g_hosts_file" 2>/dev/null
  then
    sed "s/^.*$g_entry_regex.*$/$g_resolved_ip  $g_domain/" "$g_hosts_file" > "$g_tmpfile"
  else
    cp "$g_hosts_file" "$g_tmpfile" 2>/dev/null
    echo "$g_resolved_ip  $g_domain" >> "$g_tmpfile"
  fi

  # Skip if no change needed
  if ! diff "$g_hosts_file" "$g_tmpfile" >/dev/null 2>&1
  then
    cat "$g_tmpfile" >"$g_hosts_file"
  fi
  rm -f "$g_tmpfile"  

  local rc=99
  # check for transprent tor proxy
  if curl --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 5 \
    https://check.torproject.org/api/ip 2>/dev/null | jq -e '.IsTor' | grep -q '^true$'
  then
    g_echo_note "Tor transparent proxy is active"
    rc=0
  fi

  sed -i "/$g_entry_regex/d" "$g_hosts_file" 2>/dev/null
  return $rc
}

