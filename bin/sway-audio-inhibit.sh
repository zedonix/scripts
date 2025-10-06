#!/usr/bin/env bash

POLL=2

while true; do
  pid=$(pgrep -x swayidle || true)
  [[ -z "$pid" ]] && sleep $POLL && continue

  playing=$(pactl list short sink-inputs | wc -l)
  recording=$(pactl list short source-outputs | wc -l)
  active=$((playing + recording))

  state=$(ps -o s= -p "$pid" | awk '{print substr($1,1,1)}' || echo "")

  if ((active > 0)); then
    [[ "$state" != "T" ]] && kill -STOP "$pid"
  else
    [[ "$state" == "T" ]] && kill -CONT "$pid"
  fi

  sleep $POLL
done
