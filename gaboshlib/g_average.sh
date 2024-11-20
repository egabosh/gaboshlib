function g_average {
  cat | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; }'
}