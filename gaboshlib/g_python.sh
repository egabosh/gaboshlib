function g_python {

  # function for running python in the background
  # $g_fd_python_in $g_fd_python_out have to be global

  unset g_python_result

  local g_jobs
  mapfile -t g_jobs < <(jobs -r)
  # check if python is already running
  if [[ -z $g_fd_python_in || -z $g_fd_python_out || ${g_jobs[*]} != *python3* ]]
  then
    local python_input="$g_tmp/$$-g_python_input"
    local python_output="$g_tmp/$$-g_python_output"
    local python_error="$g_tmp/$$-g_python_error"
    # create fifo pipe
    rm -f "$python_input" "$python_output" "$python_error"
    mkfifo "$python_input" "$python_output" "$python_error"
    # run bc in background und switch i/o to pipes
    timeout -k 260s 240s python3 -iuq  < "$python_input" > "$python_output" 2> "$python_error" &
    # store in filedescriptiors
    exec {g_fd_python_in}> "$python_input"
    exec {g_fd_python_out}< "$python_output"
    exec {g_fd_python_error}< "$python_error"
  fi
 
  # read potential old output
  read -t 0.001 -u ${g_fd_python_out} g_python_result_old
 
  # send python command
  echo "$@
print('')" >&${g_fd_python_in}

  # read output
  read -u ${g_fd_python_out} g_python_result

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

