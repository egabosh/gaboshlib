function g_calc {

  # function for calculating via bc running in the background (much faster then starting bc every time)
  # $g_fd_bc_in $fd_bc_out have to be global

  unset g_calc_result

  local g_jobs g_job_nums
  mapfile -t g_jobs < <(jobs -l)

  # check if bc is already running
  if [[ -z "$g_fd_bc_in" || -z "$g_fd_bc_out" || ${g_jobs[*]} != *bc* ]]
  then
    # close the fds of a previous bc so they do not pile up
    [[ -n "$g_fd_bc_in" ]] && exec {g_fd_bc_in}>&- 2>/dev/null
    [[ -n "$g_fd_bc_out" ]] && exec {g_fd_bc_out}<&- 2>/dev/null
    unset g_fd_bc_in g_fd_bc_out

    # Use ${BASHPID} instead of $$ so every (sub)shell gets its own bc daemon
    # and fifo pair. In subshells $$ stays at the parent PID, so all of them
    # raced on the same fifo pair: requests and responses got interleaved and
    # orphaned daemons of finished subshells kept consuming/reading the shared
    # fifos, which produced silent wrong results. ${BASHPID} is the PID of the
    # current (sub)shell, so each caller is isolated.
    local bc_input="$g_tmp/${BASHPID}-g_bc_input"
    local bc_output="$g_tmp/${BASHPID}-g_bc_output"
    # create fifo pipe
    rm -f "$bc_input" "$bc_output"
    mkfifo "$bc_input" "$bc_output"
    # run bc in background und switch i/o to pipes
    timeout -k 260s 240s bc -ql < "$bc_input" > "$bc_output" 2>&1 &
    # store in filedescriptiors
    exec {g_fd_bc_in}> "$bc_input"
    exec {g_fd_bc_out}< "$bc_output"
  fi

  # send calculation and read result.
  # bc is terminated by 'timeout -k 260s 240s' (or dies on its own). A write
  # that then hits the dead reader makes the fifo raise SIGPIPE, whose default
  # action terminates the calling shell - that killed dabo-bot.sh with rc=0
  # right here. Ignore SIGPIPE for the write and restore the previous
  # disposition afterwards, so a dead bc only fails this single call (the next
  # call starts a fresh bc).
  local f_trap_pipe f_write_rc
  f_trap_pipe=$(trap -p PIPE)
  trap '' PIPE
  echo "$1" >&${g_fd_bc_in} 2>/dev/null
  f_write_rc=$?
  if [[ -n "$f_trap_pipe" ]]
  then
    eval "$f_trap_pipe"
  else
    trap - PIPE
  fi

  # write failed -> bc is gone: drop the fds so the next call starts a new bc
  if (( f_write_rc != 0 ))
  then
    [[ -n "$g_fd_bc_in" ]] && exec {g_fd_bc_in}>&- 2>/dev/null
    [[ -n "$g_fd_bc_out" ]] && exec {g_fd_bc_out}<&- 2>/dev/null
    unset g_fd_bc_in g_fd_bc_out
    unset g_calc_result
    return 1
  fi

  read -u ${g_fd_bc_out} g_calc_result

  # check if there is a output
  if [ -z "$g_calc_result" ]
  then
    echo "${FUNCNAME} $@" 1>&2
    unset g_calc_result
    return 1
  fi 

  # fix bc output -> change for example .224 to 0.224 and -.224 to -0.224
  [[ $g_calc_result  == "."* ]] && g_calc_result="0$g_calc_result"
  [[ $g_calc_result  == "-."* ]] && g_calc_result="-0.${g_calc_result#-.}"

  # remove ending 0 if for example 4.54300000
  while [[ $g_calc_result =~ [.] && ${g_calc_result: -1} == "0" ]]
  do
    g_calc_result=${g_calc_result: : -1}
  done

  # remove ending . for example "100." -> 100
  [[ $g_calc_result  == *"." ]] && g_calc_result=${g_calc_result%?}

  # check output
  if ! g_num_valid_number "$g_calc_result"
  then
    echo "${FUNCNAME} $@" 1>&2
    unset g_calc_result
    return 1
  fi
}

