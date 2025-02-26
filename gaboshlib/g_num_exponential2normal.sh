#!/bin/bash
function g_num_exponential2normal {
  g_num_exponential2normal_result=""
  [ -z "$1" ] && return 1
  # if there is a exponential number (for example 9.881e-05) convert it to "normal" notation
  if [[ "$1" =~ e-[0-9] ]]
  then
    # convert
    printf -v g_num_exponential2normal_result -- "%.12f" "$1"
    # remove ending 0
    if [[ $g_num_exponential2normal_result =~ \. ]]
    then
      g_num_exponential2normal_result=${g_num_exponential2normal_result%%+(0)}
      g_num_exponential2normal_result=${g_num_exponential2normal_result%%.}
    fi
    return 0
  else
    g_num_exponential2normal_result=$1
    return 2
  fi
}
