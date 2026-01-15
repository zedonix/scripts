#!/usr/bin/env bash
watch -n 1 '
echo "=== TOP CPU (aggregate) ==="
ps -eo comm,%cpu --no-headers | awk "{cpu[\$1]+=\$2} END{for (c in cpu) printf \"%6.2f%% %s\n\", cpu[c], c}" | sort -nr | head -n 12
echo
echo "=== TOP MEM (aggregate) ==="
ps -eo comm,%mem --no-headers | awk "{mem[\$1]+=\$2} END{for (c in mem) printf \"%6.2f%% %s\n\", mem[c], c}" | sort -nr | head -n 12
'
