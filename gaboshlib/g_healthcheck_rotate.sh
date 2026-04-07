#!/bin/bash

function g_healthcheck_rotate {
  [[ -z "$HEALTHCHECK_FILE" ]] && return 1
  [[ -s "$HEALTHCHECK_FILE" ]] && sort -u "$HEALTHCHECK_FILE" >"${HEALTHCHECK_FILE}.done"
  printf -v rotate_date '%(%Y-%m-%d %H:%M:%S)T'
  >$HEALTHCHECK_FILE
  g_echo_ok "Healthckecks since $rotate_date"
}

