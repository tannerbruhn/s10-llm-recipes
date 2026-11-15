#!/bin/sh
# swaptest.sh (on the phone): one chat request per model given, through the router on :8080.
# Prints the wall time (includes any model swap) and the server's own prompt/generation speed.
# usage: swaptest.sh ornith-1.0-9b bonsai-27b ornith-1.0-9b
K=$(cat /etc/s10-llm/api-key)
for m in "$@"; do
  t0=$(date +%s)
  r=$(curl -s -m 1800 http://127.0.0.1:8080/v1/chat/completions -H "Authorization: Bearer $K" -H 'Content-Type: application/json' \
    -d "{\"model\":\"$m\",\"max_tokens\":48,\"temperature\":0,\"chat_template_kwargs\":{\"enable_thinking\":false},\"messages\":[{\"role\":\"user\",\"content\":\"In two sentences, why does a phone throttle its CPU when it gets hot?\"}]}")
  t1=$(date +%s)
  echo "$m: wall $((t1-t0)) s | $(echo "$r" | grep -o '"prompt_per_second":[0-9.]*\|"predicted_per_second":[0-9.]*\|"predicted_n":[0-9]*' | tr '\n' ' ')| bat $(cat /sys/class/power_supply/max170xx_battery/capacity)% | mem avail $(free -m | awk '/Mem/{print $7}') MB"
  echo "  $(echo "$r" | grep -o '"content":"[^"]*' | head -1 | cut -c12-220)"
done
