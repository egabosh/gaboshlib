#!/bin/bash

# thanks to dylanaraps - https://github.com/dylanaraps/nosj

# function g_json gives back the associative array $g_json
# parsed json by stdin or file in $1
#
# To get keys use: ${!g_json[@]}
# To get values use ${g_json[@]}
# To get specific key use ${g_json[keyname]}

function g_json {
  IFS= g_json_tokenize < "${1:-/dev/stdin}"
  IFS= g_json_parse
}

function g_json_tokenize {
  unset tokens
  declare -a tokens
  local j str
  while read -rN 1; do
    case $REPLY in
      [\{\}\[\],])
        [[ $str ]] && j+=$REPLY
        [[ $str ]] || { tokens+=("$j" "$REPLY"); j=; }
      ;;
      :)
        [[ $str ]] && j+=:
        [[ $str ]] || j+='\ '
      ;;
         [[:space:]])
         [[ $str ]] && j+=$REPLY
      ;;
         [\"\'])
         [[ $str ]] && str= || str=1
         [[ ${j: -1} == \\ ]] && { str=1; j+=$REPLY; }
       ;;
       *) j+=$REPLY ;;
     esac
  done
}

function g_json_parse {
  unset -v g_json
  declare -Ag g_json
  local i key key_plain objects o val out
  for ((i=0;i<${#tokens[@]};i++)) {
    case ${tokens[i]} in
      \{|\[)
        objects+=("${tokens[i-1]}")
      ;;
      \}|\])
        unset 'objects[-1]'
      ;;
      *\\\ *)
        key=${objects[*]//\\ /.}${tokens[i]/\\ *}
        key_plain=index_${key//[^A-Za-z0-9]/_}
        val=${tokens[i]/*\\ }
        if [[ -n ${g_json[$key]} ]]
        then
          [[ -n ${g_json[${key}[0]]} ]] || {
            g_json["${key}[0]"]=${g_json[$key]}
            printf -v o 'g_json[%q]=%q' "${key}[0]" "${g_json[$key]}"
            out+=("$o")
          }
          declare -i "$key_plain+=1"
          printf -v o 'g_json[%q]=%q' "${key}[${!key_plain}]" "$val"
          out+=("$o")
        elif [[ $val ]]; then
          g_json["$key"]=$val
          printf -v o 'g_json[%q]=%q' "$key" "$val"
          out+=("$o")
        fi
      ;;
    esac
  }
}

