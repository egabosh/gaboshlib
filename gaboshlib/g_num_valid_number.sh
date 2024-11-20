function g_num_valid_number {
  local arg
  for arg in "$@"
  do
    if ! [[ $arg =~ ^(-)?(\.)?[0-9]+(\.)?([0-9]+)?$ ]]
    then
      echo "\"$arg\": Not a valid number" 1>&2
      g_traceback
      return 1
    fi
  done
  if [ -z "$1" ]
  then
    echo "No argument given" 1>&2
    g_traceback
    return 2
  fi
}
