function g_lock {

  # create lockfile for file

  # file to lock
  local f_file="$1"

  # seconds to remove lock if older
  local f_remove_lock="$2"

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
    if grep -q "^$g_scriptname ${FUNCNAME[2]}->${FUNCNAME[1]} $$ " "${f_file}.lock"
    then
      g_echo_debug "remove logfile ${f_file}.lock with same '^$g_scriptname $FUNCNAME $$ '"
      rm "${f_file}.lock"
    else
      g_echo_warn "${FUNCNAME[1]}: ${f_file}.lock already exists $(cat "${f_file}.lock")"
      return 1
    fi
  else
    # remove if empty
    g_echo_debug "remove emtpy logfile ${f_file}.lock"
    rm -f "${f_file}.lock"
  fi

  printf "$g_scriptname ${FUNCNAME[2]}->${FUNCNAME[1]} $$ %(%Y-%m-%d %H:%M:%S)T" >"${f_file}.lock"
  g_lock_resule="${f_file}.lock"

}

