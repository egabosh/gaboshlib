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
    [ -p "$python_input" ] || mkfifo "$python_input"
    [ -p "$python_output" ] || mkfifo "$python_output"
    [ -p "$python_error" ] || mkfifo "$python_error"
    # run bc in background und switch i/o to pipes
    python3 -iuq  < "$python_input" > "$python_output" 2> "$python_error" &
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


function g_python_old {

  local g_python_tmp=${g_tmp}/$$
  g_python_out=${g_python_tmp}/python-out
  local g_python_in=${g_python_tmp}/python-in
  local g_python_error=${g_python_tmp}/python-error
  local g_python_jobs
  mapfile -t g_python_jobs < <(jobs -r)
  unset g_python_result

  # Use python in backround for multiple python commands running much faster
  #if [ -z "${g_python_running}" ]
  if [[ ${g_python_jobs[*]} != *python-pipeexec.py* ]]
  then
    mkdir -p ${g_python_tmp}
    if [ -s ${g_python_error} ]
    then
      g_echo_error "From last python run: $(cat ${g_python_error})"
    fi
    [ -p ${g_python_in} ] || mkfifo ${g_python_in}
    echo "while 1:
  exec(open(\"${g_python_in}\").read())
  print('DONE')
" >${g_python_tmp}/python-pipeexec.py

    # python stream channel
    { python3 -u ${g_python_tmp}/python-pipeexec.py >>${g_python_out} 2>>${g_python_error} & }
    g_python_running="true"
  fi

  # do python
  >${g_python_out}
  >${g_python_error}
  echo $@ >${g_python_in}

  while true
  do
   
    # Check for output
    if [ -s ${g_python_out} ]
    then
      mapfile -t g_python_result <${g_python_out}
      if [[ ${g_python_result[-1]} == DONE ]]
      then
        # remove the DONE output (last array element
        unset g_python_result[-1]
        break
      fi
    fi

    # Check for error
    mapfile -t g_python_jobs < <(jobs -r)
    if [ -s "${g_python_error}" ] || [[ ${g_python_jobs[*]} != *python-pipeexec.py* ]]
    then
      g_echo_error "Python Progress not running:
$(cat ${g_python_error})"
      return 1
    fi

    # sleep a short time
    sleep 0.1
  done

}

