function g_calc {

  # function for calculating via bc running in the background (much faster then starting bc every time)
  # $g_fd_bc_in $fd_bc_out have to be global

  unset g_calc_result

  local g_jobs g_job_nums
  mapfile -t g_jobs < <(jobs -l)

#  # check for multiple running bc jobs
#  local g_bc_count=0
#  for g_job in "${g_jobs[@]}"
#  do
#    # Prüfen, ob die Jobzeile "bc -ql" enthält
#    if [[ $g_job =~ "bc -ql" ]]; then
#      ((g_bc_count++))
#      g_job="${g_job#* }"
#      g_job_nums="$g_job_nums ${g_job%% *}"
#    fi
#  done
#  # kill all if more then 1
#  if (( g_bc_count > 1 ))
#  then
#    for g_job in $g_job_nums
#    do
#      kill -9 "$g_job"
#    done
#    mapfile -t g_jobs < <(jobs -l)
#  fi
  
  # check if bc is already running
  if [[ -z "$g_fd_bc_in" || -z "$g_fd_bc_out" || ${g_jobs[*]} != *bc* ]]
  then
    local bc_input="$g_tmp/$$-g_bc_input"
    local bc_output="$g_tmp/$$-g_bc_output"
    # create fifo pipe
    [ -p "$bc_input" ] || mkfifo "$bc_input"
    [ -p "$bc_output" ] || mkfifo "$bc_output"
    # run bc in background und switch i/o to pipes
    timeout -k 260s 240s bc -ql < "$bc_input" > "$bc_output" 2>&1 &
    # store in filedescriptiors
    exec {g_fd_bc_in}> "$bc_input"
    exec {g_fd_bc_out}< "$bc_output"
  fi
  # send calculation and read result
  echo "$1" >&${g_fd_bc_in}
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

  # remove ending 0 if for exabple 4.54300000
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

