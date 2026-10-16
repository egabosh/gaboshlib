function g_python {

  # function for running python in the background
  # $g_fd_python_in $g_fd_python_out $g_fd_python_error have to be global

  # seconds to wait for a python answer before the daemon is treated as hung
  [ -z "$g_python_timeout" ] && g_python_timeout=45

  unset g_python_result

  local g_jobs
  mapfile -t g_jobs < <(jobs -r)

  # check if python is already running
  if [[ -z $g_fd_python_in || -z $g_fd_python_out || -z $g_fd_python_error || ${g_jobs[*]} != *python3* ]]
  then
    # close the fds of a previous python so they do not pile up
    [[ -n "$g_fd_python_in" ]] && exec {g_fd_python_in}>&- 2>/dev/null
    [[ -n "$g_fd_python_out" ]] && exec {g_fd_python_out}<&- 2>/dev/null
    [[ -n "$g_fd_python_error" ]] && exec {g_fd_python_error}<&- 2>/dev/null
    unset g_fd_python_in g_fd_python_out g_fd_python_error

    # Use ${BASHPID} instead of $$ so every (sub)shell gets its own daemon and
    # fifo triplet. In subshells $$ stays at the parent PID, so all of them
    # raced on the same fifos and interleaved their commands and responses.
    local python_input="$g_tmp/${BASHPID}-g_python_input"
    local python_output="$g_tmp/${BASHPID}-g_python_output"
    local python_error="$g_tmp/${BASHPID}-g_python_error"
    # create fifo pipe
    rm -f "$python_input" "$python_output" "$python_error"
    mkfifo "$python_input" "$python_output" "$python_error"
    # run python in background and remember its pid so a hung daemon can be killed
    python3 -iuq < "$python_input" > "$python_output" 2> "$python_error" &
    g_python_pid=$!
    # store in filedescriptiors
    exec {g_fd_python_in}> "$python_input"
    exec {g_fd_python_out}< "$python_output"
    exec {g_fd_python_error}< "$python_error"
  fi

  # read potential old output
  read -t 0.001 -u ${g_fd_python_out} g_python_result_old

  # send python command.
  # A write that hits a dead reader makes the fifo raise SIGPIPE, whose default
  # action terminates the calling shell. Ignore SIGPIPE for the write and
  # restore the previous disposition afterwards, so a dead daemon only fails
  # this single call (the next call starts a fresh daemon).
  local f_trap_pipe f_write_rc
  f_trap_pipe=$(trap -p PIPE)
  trap '' PIPE
  echo "$@
print('')" >&${g_fd_python_in} 2>/dev/null
  f_write_rc=$?
  if [[ -n "$f_trap_pipe" ]]
  then
    eval "$f_trap_pipe"
  else
    trap - PIPE
  fi

  # read the answer with a timeout: a hung python must not block the caller
  if (( f_write_rc != 0 )) || ! read -t "$g_python_timeout" -u ${g_fd_python_out} g_python_result
  then
    # python is gone or hung: kill it and drop the fds so the next call starts
    # a fresh daemon instead of reusing the dead/hung one.
    # Capture the kernel state and wait channel of the hung daemon so a
    # recurring hang can be diagnosed from the log.
    local f_stat f_state f_wchan
    [[ -r /proc/$g_python_pid/stat ]] && read -r f_stat < "/proc/$g_python_pid/stat"
    f_state="${f_stat#*) }"
    f_state="${f_state%% *}"
    [[ -r /proc/$g_python_pid/wchan ]] && f_wchan=$(<"/proc/$g_python_pid/wchan")
    g_echo_error "${FUNCNAME} TIMEOUT ${g_python_timeout}s (pid=$g_python_pid state=${f_state:-?} wchan=${f_wchan:-?}): $@"
    kill -9 "$g_python_pid" 2>/dev/null
    wait "$g_python_pid" 2>/dev/null
    [[ -n "$g_fd_python_in" ]] && exec {g_fd_python_in}>&- 2>/dev/null
    [[ -n "$g_fd_python_out" ]] && exec {g_fd_python_out}<&- 2>/dev/null
    [[ -n "$g_fd_python_error" ]] && exec {g_fd_python_error}<&- 2>/dev/null
    unset g_fd_python_in g_fd_python_out g_fd_python_error g_python_pid
    unset g_python_result
    return 1
  fi

  local g_errline
  local g_err_msg

  # look for error
  while read -t 0.001 -u ${g_fd_python_error} g_errline
  do
    [[ "$g_errline" =~ \>\>\>$ ]] && break
    [ -z "$g_errline" ] && break
    g_err_msg="$g_err_msg
$g_errline"
  done
  if [ -n "$g_err_msg" ]
  then
    g_echo_error "$g_err_msg"
    return 1
  fi

}
