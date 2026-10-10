function g_calc {

  # Function for calculating via bc.
  # Synchronous call instead of the previous background/fifo variant: the old
  # approach desynced because all subshells shared the same fifo path ($$) and
  # interleaved writes/reads produced wrong or empty results.

  unset g_calc_result

  # require a non-empty calculation
  if [[ -z "$1" ]]
  then
    echo "${FUNCNAME}: No calculation given" 1>&2
    return 1
  fi

  # run bc synchronously; discard stderr so error text cannot leak into the result
  g_calc_result=$(printf '%s\n' "$1" | timeout 10 bc -l 2>/dev/null)

  # result must be a plain number (empty means bc errored, e.g. divide by zero)
  if ! [[ "$g_calc_result" =~ ^-?[0-9]*\.?[0-9]+$ ]]
  then
    echo "${FUNCNAME}: No valid result for \"$1\" (got \"$g_calc_result\")" 1>&2
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
}
