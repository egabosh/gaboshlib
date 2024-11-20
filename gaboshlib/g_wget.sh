function g_wget {
  wget -T 10 -t 2 \
   --header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36" \
   --header="Content-Type: application/json" \
   --header="Accept-Language: en-US,en," \
   $@
}
