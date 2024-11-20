function g_kill_all_background_jobs {
  [ -z "$1" ] &&
  sleep 0.1
  g_array "$(jobs -p)" g_pids
  if [ -n "${g_pids[0]}" ]
  then
    if [ -z "$1" ]
    then
      kill -9 ${g_pids[*]} >/dev/null 2>&1
    else
      local g_cmdline="$1"
      local g_proc
      local g_pid
      for g_pid in "${g_pids[@]}"
      do
        read g_proc < <(tr "\0" " " < /proc/${g_pid}/cmdline)
        [ "$g_proc" = "$g_cmdline" ] && kill -9 $g_pid >/dev/null 2>&1
      done
    fi
  fi
  return 0
}

