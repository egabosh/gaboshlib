function g_num_exponential2normal_file {
  # changes expionential numbers in normal notation in given file
  local g_file=$1
  local g_substitution g_exnum
  for g_exnum in $(egrep -o -i "[0-9]+\.[0-9]+e[\+\-][0-9]+" "$g_file" | sort -u)
  do
    g_num_exponential2normal $g_exnum && g_substitution="${g_substitution}s/${g_exnum}/${g_num_exponential2normal_result}/g;"
  done
  sed -i "${g_substitution}" "$g_file" && return 0
}

