#!/usr/bin/env bash

interval=1

# ---- CPU helpers ----
read_cpu() {
  read -r _ u n s i w irq sirq steal _ </proc/stat
  total=$((u + n + s + i + w + irq + sirq + steal))
  idle=$((i + w))
  echo "$total $idle"
}

read prev_total prev_idle < <(read_cpu)

while true; do
  sleep "$interval"

  # ---- Time ----
  timestamp=$(date +"%a %d/%m %H:%M")

  # ---- CPU ----
  read total idle < <(read_cpu)
  dt=$((total - prev_total))
  di=$((idle - prev_idle))
  prev_total=$total
  prev_idle=$idle
  ((dt > 0)) && cpu=$(((dt - di) * 100 / dt)) || cpu=0

  # ---- Load ----
  read load _ </proc/loadavg

  # ---- Memory / Swap ----
  while read -r key val _; do
    case "$key" in
    MemTotal:) mem_total=$val ;;
    MemAvailable:) mem_avail=$val ;;
    SwapTotal:) swap_total=$val ;;
    SwapFree:) swap_free=$val ;;
    esac
  done </proc/meminfo

  mem=$(((mem_total - mem_avail) * 100 / mem_total))
  mem_avail_g=$((mem_avail / 1024 / 1024))

  ((swap_total > 0)) &&
    swap=$(((swap_total - swap_free) * 100 / swap_total)) ||
    swap=0

  # ---- Battery + time remaining ----
  if [ -d /sys/class/power_supply/BAT0 ]; then
    ps=/sys/class/power_supply/BAT0
    read cap <"$ps/capacity"
    read status <"$ps/status"

    # energy_* preferred, charge_* fallback
    if [ -f "$ps/energy_now" ]; then
      read now <"$ps/energy_now"
      read power <"$ps/power_now"
    elif [ -f "$ps/charge_now" ]; then
      read now <"$ps/charge_now"
      read power <"$ps/current_now"
    else
      power=0
    fi

    if [[ $status == Discharging && $power -gt 0 ]]; then
      secs=$((now * 3600 / power))
      h=$((secs / 3600))
      m=$(((secs % 3600) / 60))
      time_left=$(printf "%d:%02d" "$h" "$m")
      bat="BAT ${cap}% ${time_left}"
    elif [[ $status == Charging ]]; then
      bat="BAT ${cap}% +"
    else
      bat="BAT ${cap}%"
    fi
  else
    bat="BAT N/A"
  fi

  echo "[LOAD $load | CPU ${cpu}% | MEM ${mem}% (${mem_avail_g}G) | SWAP ${swap}% | $bat | $timestamp]"
done
