function g_traceback {
  local deptn=${#FUNCNAME[@]}
  local i
  for ((i=1; i<$deptn; i++)); do
    local func="${FUNCNAME[$i]}"
    local line="${BASH_LINENO[$((i-1))]}"
    local src="${BASH_SOURCE[$((i-1))]}"
    printf '%*s' $i '' # indent
    echo "at: $func, $src, line $line" 1>&2
  done
  echo "$@" 1>&2
}
