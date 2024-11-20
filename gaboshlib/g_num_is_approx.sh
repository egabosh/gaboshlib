function g_num_is_approx {
  
  # check if $1 is in percentage range ($3 and $4) to $2
  local f_num=$1
  local f_base=$2
  local f_percentage_up=$3
  local f_percentage_down=$4

  # Check for valid decimal number
  
  g_num_valid_number "${f_num}" "${f_base}" "${f_percentage_up}" "${f_percentage_down}" || return 1
 
  g_calc "${f_base} - (${f_base} / 100 * ${f_percentage_down})"
  local f_from=${g_calc_result}
  g_calc "${f_base} + (${f_base} / 100 * ${f_percentage_up})"
  local f_to=${g_calc_result}

  g_num_is_between ${f_num} ${f_from} ${f_to}
}
