function g_wget {

  [[ -z "$g_proxys" ]] && g_proxys="none"
  
  for g_proxy in $g_proxys
  do
    export http_proxy=$g_proxy
    export https_proxy=$g_proxy
    export ftp_proxy=$g_proxy
    [[ $g_proxy = none ]] && unset http_proxy https_proxy ftp_proxy

    wget -T 10 -t 2 \
     --header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36" \
     --header="Content-Type: application/json" \
     --header="Accept-Language: en-US,en," \
     $@ && break
  done
}
