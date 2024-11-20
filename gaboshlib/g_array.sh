function g_array {
  local g_filename=$1
  local g_arrayname=$2
  local g_delimeter=$3
  unset -v g_array

  [ -n "$g_delimeter" ] && g_delimeter="-d${g_delimeter}"
  if [ -f "$g_filename" ]
  then
    mapfile $g_delimeter -tn 0 g_array < "$g_filename"
  else
    mapfile $g_delimeter -tn 0 g_array <<< "$g_filename"
  fi
  
  # remove newlines
  g_array=("${g_array[@]%$'\n'}")
  declare -ng $g_arrayname=g_array

}

