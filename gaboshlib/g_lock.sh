function g_lock {

  # create lockfile for file

  # file to lock
  local f_file="$1"

  # seconds to remove lock if older
  local f_remove_lock="$2"

  # id of this container, an owner is only trusted if it matches the lock
  local f_lock_host="${HOSTNAME:-$(</proc/sys/kernel/hostname)}"

  if [[ -n "$f_remove_lock" ]]
  then
    if g_olderthen "${f_file}.lock" "$f_remove_lock" 
    then
      g_echo_debug "remove logfile ${f_file}.lock older then $f_remove_lock seconds"
      rm "${f_file}.lock"
    fi
  fi

  if [[ -s "${f_file}.lock" ]]
  then
    if grep -q "^$g_scriptname ${FUNCNAME[2]}->${FUNCNAME[1]} $BASHPID " "${f_file}.lock"
    then
      g_echo_debug "remove logfile ${f_file}.lock with same '^$g_scriptname $FUNCNAME $BASHPID '"
      rm "${f_file}.lock"
    else
      # drop a lock left behind by a dead process of THIS container; a
      # different container carries a different host id, so a foreign lock is
      # never dropped here (only the age check above may remove it).
      # "dead" means the process is gone (no /proc entry) or already a zombie
      # (state Z), which 'kill -0' alone would still report as alive
      local f_lock_pid="$(cut -d' ' -f3 "${f_file}.lock" 2>/dev/null)"
      local f_lock_state=""
      [[ -r /proc/${f_lock_pid}/stat ]] && read -r f_lock_state < "/proc/${f_lock_pid}/stat"
      f_lock_state="${f_lock_state#*) }"
      f_lock_state="${f_lock_state%% *}"
      if grep -q "host=${f_lock_host}" "${f_file}.lock" && [[ -n "$f_lock_pid" ]] && [[ -z "$f_lock_state" || "$f_lock_state" == "Z" ]]
      then
        g_echo_debug "remove orphaned logfile ${f_file}.lock of dead pid $f_lock_pid"
        rm "${f_file}.lock"
      fi

      # if the lock still exists a concurrent run owns it
      if [[ -s "${f_file}.lock" ]]
      then
        g_echo_warn "${FUNCNAME[1]}: ${f_file}.lock already exists $(cat "${f_file}.lock")"
        return 1
      fi
    fi
  else
    # remove if empty
    if [[ -e "${f_file}.lock" ]]
    then
      g_echo_debug "remove emtpy logfile ${f_file}.lock"
      rm -f "${f_file}.lock"
    fi
  fi

  # BASHPID (not $$): parallel subshells share $$ and would treat the lock of
  # a sibling subshell as their own, so the lock would not exclude anyone
  printf "$g_scriptname ${FUNCNAME[2]}->${FUNCNAME[1]} $BASHPID %(%Y-%m-%d %H:%M:%S)T host=${f_lock_host}" >"${f_file}.lock"
  g_lock_resule="${f_file}.lock"

}
