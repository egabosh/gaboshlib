function g_num_is_between {

  local f_num=$1
  local f_between1=$2
  local f_between2=$3

  # Check for integer (can be done with bash itself)
  if [[ $f_num =~ ^[0-9]+$ ]] && [[ $f_between1 =~ ^[0-9]+$ ]] && [[ $f_between2 =~ ^[0-9]+$ ]]
  then
    # Check which is the low (from) and the high (to) number
    if [ $f_between1 -lt $f_between2 ]
    then
      local f_from=$f_between1
      local f_to=$f_between2
    else
      local f_from=$f_between2
      local f_to=$f_between1
    fi
    # Check if given number is in or out range
    if [ $f_num -lt $f_from ] || [ $f_num -gt $f_to ]
    then
      return 1
    else
      return 0
    fi
  fi

  # Check for valid number
  g_num_valid_number "$f_num" "$f_between1" "$f_between2" || return 1

  # Check which is the low (from) and the high (to) number
  g_calc "$f_between1 < $f_between2"
  if [ "$g_calc_result" -ne 0 ]
  then
    local f_from=$f_between1
    local f_to=$f_between2
  else
    local f_from=$f_between2
    local f_to=$f_between1
  fi
  # Check if given number is in or out range
  g_calc "$f_num < $f_from"
  local g_calc_result_from="$g_calc_result"
  g_calc "$f_num > $f_to"
  local g_calc_result_to="$g_calc_result"
  if [ "$g_calc_result_from" -ne 0 ] || [ "$g_calc_result_to" -ne 0 ]
  then
    return 1
  else
    return 0
  fi
}
