function g_olderthen {

  # check if file older then given seconds
  local file="$1"
  local seconds="$2"
  [ -e "$file" ] || return 1
  (( $EPOCHSECONDS - $(stat -c %Y "$file") > $seconds ))

}

