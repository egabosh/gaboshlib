function g_num_is_higher_equal {

  local f_num=$1
  local f_checkhigher=$2

  # Check for integer (can be done with bash itself)
  if [[ ${f_num} =~ ^[0-9]+$ ]] && [[ ${f_checkhigher} =~ ^[0-9]+$ ]]
  then
    # Check which is the low (from) and the high (to) number
    if [ "${f_num}" -ge "${f_checkhigher}" ]
    then
      return 0
    else
      return 1
    fi
  fi

  # Check for valid number
  g_num_valid_number "$f_num" "$f_checkhigher" || return 1
 
  g_calc "${f_num} >= ${f_checkhigher}"
  if [ "${g_calc_result}" -ne 0 ]
  then
    return 0
  else
    return 1
  fi
}

function g_num_is_higher {

  local f_num=$1
  local f_checkhigher=$2

  # Check for integer (can be done with bash itself)
  if [[ ${f_num} =~ ^[0-9]+$ ]] && [[ ${f_checkhigher} =~ ^[0-9]+$ ]]
  then
    # Check which is the low (from) and the high (to) number
    if [ "${f_num}" -gt "${f_checkhigher}" ]
    then
      return 0
    else
      return 1
    fi
  fi

  # Check for valid number
  g_num_valid_number "$f_num" "$f_checkhigher" || return 1
  
  g_calc "${f_num} > ${f_checkhigher}"
  if [ "${g_calc_result}" -ne 0 ]
  then
    return 0
  else
    return 1
  fi
}
