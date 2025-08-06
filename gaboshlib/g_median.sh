function g_median {
  unset g_median_result

  # Array with numbers
  local g_numbers=("$@")

  # read from stdin if no arguments
  [[ -z "$1" ]] && mapfile -t g_numbers

  # sort array
  local g_sorted_numbers=($(printf "%s\n" "${g_numbers[@]}" | sort -n))
  
  # number of elements
  local g_num_elements=${#g_sorted_numbers[@]}
   
  # calculate the middle
  local g_middle=$(($g_num_elements/2))

  # even/odd number 
  if (($g_num_elements % 2 == 1))
  then
    # odd number
    g_median_result="${g_sorted_numbers[$g_middle]}"
  else
    # even number
    g_calc "(${g_sorted_numbers[$g_middle - 1]} + ${g_sorted_numbers[$g_middle]}) / 2"
    g_median_result="$g_calc_result"
  fi
}
