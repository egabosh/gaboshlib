function g_num_is_lower_equal {

  local f_num=$1
  local f_checklower=$2

  # Check for integer (can be done with bash itself)
  if [[ ${f_num} =~ ^[0-9]+$ ]] && [[ ${f_checklower} =~ ^[0-9]+$ ]]
  then
    # Check which is the low (from) and the high (to) number
    if [ "${f_num}" -le "${f_checklower}" ]
    then
      return 0
    else
      return 1
    fi
  fi

  # Check for valid number
  g_num_valid_number "$f_num" "$f_checklower" || return 1
 
  g_calc "${f_num} <= ${f_checklower}"
  if [ "${g_calc_result}" -ne 0 ]
  then
    return 0
  else
    return 1
  fi
}


function g_num_is_lower {

  local f_num=$1
  local f_checklower=$2

  # Check for integer (can be done with bash itself)
  if [[ ${f_num} =~ ^[0-9]+$ ]] && [[ ${f_checklower} =~ ^[0-9]+$ ]]
  then
    # Check which is the low (from) and the high (to) number
    if [ "${f_num}" -lt "${f_checklower}" ]
    then
      return 0
    else
      return 1
    fi
  fi

  # Check for valid number
  g_num_valid_number "$f_num" "$f_checklower" || return 1
 
  g_calc "${f_num} < ${f_checklower}"
  if [ "${g_calc_result}" -ne 0 ]
  then
    return 0
  else
    return 1
  fi
}
