function g_dirname {
  g_dirname_result="${1%"${1##*[!/]}"}"
  g_dirname_result="${g_dirname_result%/*}"
  g_dirname_result=${g_dirname_result:-/}
}
