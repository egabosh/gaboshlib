function g_basename {
  g_basename_result=${1##*/}
  g_basename_result=${g_basename_result:-/}
}

