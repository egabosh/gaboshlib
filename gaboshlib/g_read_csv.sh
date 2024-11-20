function g_read_csv {
  unset v_csv_array_associative
  unset v_csv_array_associative_reverse
  unset g_csv_array

  local g_csvfile="$1"
  local g_last_lines=$2
  local g_headline=$3
  local g_separator=$4

  local g_headline_item i l r g_csv_headline_array

  # check for individual separator
  [ -z "$g_separator" ] && g_separator=","
  # only one/first character
  g_separator=${g_separator:0:1}

  # check given file
  if ! [ -s "$g_csvfile" ]
  then
    g_echo_error "${g_csvfile} does not exist or is empty"
    return 1
  fi

  # check for ,
  if ! grep -q $g_separator "$g_csvfile"
  then
    g_echo_error "${g_csvfile} does not contain \"$g_separator\""
    return 1
  fi

  # is there a headline file
  if [ -z "$g_headline" ]
  then
    [ -s "${g_csvfile}.headline" ] && g_headline=$(<"${g_csvfile}.headline")
  fi

  # if no given headline and no headlinfile use forst line
  [ -z "$g_headline" ] && g_headline=$(head -n1 "${g_csvfile}")

  # read the headline
  unset g_csv_headline_array_ref
  g_array "$g_headline" g_csv_headline_array_ref $g_separator

  # prepare varnames from headline(s)
  for g_headline_item in "${g_csv_headline_array_ref[@]}"
  do
    g_csv_headline_array+=("${g_headline_item//[^a-zA-Z0-9_]/}")
  done

  g_basename $g_csvfile
  local g_csvfile_base=${g_basename_result/\.history*.csv/}
  g_csvfile_base=${g_csvfile_base//[^a-zA-Z0-9_]/}
  g_csvfile_base=${g_csvfile_base//ECONOMY*/}

  # read last lines if defined or complete csv file
  if [ -n "$g_last_lines" ]
  then
    tail -n $g_last_lines "$g_csvfile" >"${g_tmp}/g_csv_tmp.csv"
    g_csvfile="${g_tmp}/g_csv_tmp.csv"
  fi

  # read csv file to array
  g_array "$g_csvfile" g_csv_array_ref
  g_csv_array=("${g_csv_array_ref[@]}")

  # create associative arrays forward and reverse and superarray v/vr
  declare -Ag v_csv_array_associative
  declare -Ag v_csv_array_associative_reverse
  declare -Ag v
  declare -Ag vr
  l=0  
  for (( r=${#g_csv_array[@]}-1 ; r>=0 ; r-- ))
  do 
    g_array "${g_csv_array[r]}" g_csv_line_array ,
    i=0
    # put headlines to vars with reverse numbers (last line 0)
    for g_headline_item in "${g_csv_headline_array[@]}"
    do
      #declare -g v_${l}_${g_headline_item}="${g_csv_line_array[i]}"
      # last line to vars without number
      [ "$l" = 0 ] && declare -g v_${g_headline_item}="${g_csv_line_array[i]}"
      v_csv_array_associative[${g_headline_item}_${r}]="${g_csv_line_array[i]}"
      v_csv_array_associative_reverse[${g_headline_item}_${l}]="${g_csv_line_array[i]}"
      if [ -z "${g_csvfile_base}" ]
      then
        v[${g_headline_item}_${r}]=${g_csv_line_array[i]}
        vr[${g_headline_item}_${l}]=${g_csv_line_array[i]}
      else
        v[${g_csvfile_base}_${g_headline_item}_${r}]=${g_csv_line_array[i]}
        vr[${g_csvfile_base}_${g_headline_item}_${l}]=${g_csv_line_array[i]}
      fi
      ((i++))
    done
    ((l++))
  done
}

