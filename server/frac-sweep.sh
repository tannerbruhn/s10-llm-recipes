#!/bin/sh
# Root on a phone: sweep GGML_S10_GPU_FRAC for the 27B with the production llama-bench and settings; each value from a
# cool start (<50 C) and a dropped page cache. Prints tg (generation) and pp2 per share, then the best tg share.
# Usage: frac-sweep.sh [shares...]   (default 0.25 0.30 0.35 0.40 0.45). Stop the LLM service first.
SH=${*:-0.25 0.30 0.35 0.40 0.45}
B=/home/user/llama-s10/build-mali/bin; LB=/home/user/llama-s10-rel/bin/llama-bench; [ -x $LB ] || LB=$B/llama-bench
M=/home/user/models/Bonsai2-27B-PTQ1_0-Condensed-P2TG.gguf
D=/sys/class/devfreq/18500000.gpu; echo 156000000 > $D/min_freq; echo 702000000 > $D/max_freq; echo 702000000 > $D/min_freq
temp() { for z in /sys/class/thermal/thermal_zone*; do [ "$(cut -c1-6 $z/type)" = cpucl2 ] && echo $(($(cat $z/temp)/1000)); done; }
best=""; bt=0
for f in $SH; do
  for i in $(seq 1 60); do [ "$(temp)" -lt 50 ] && break; sleep 10; done
  sync; echo 3 > /proc/sys/vm/drop_caches
  r=$(OCL_ICD_VENDORS=/home/user/mesa-idp/vendors RUSTICL_ENABLE=panfrost GGML_OPENCL_PLATFORM=0 GGML_S10_GPU_FRAC=$f GGML_S10_GPU_MINMB=6 \
      GGML_S10_INT2=all GGML_S10_INT2_POOL=/dev/s10cpumem GGML_S10_INT2_POOL_MB=184 LD_LIBRARY_PATH=$B \
      $LB -m $M -t 4 -C 0xf0 --cpu-strict 1 -p 2 -n 32 -r 3 2>&1 | grep -E "pp2|tg32" | awk -F'|' '{print $(NF-2) $(NF-1)}' | tr -s ' ' | tr '\n' ' ')
  tg=$(echo "$r" | grep -oE "tg32 [0-9.]+" | cut -d' ' -f2)
  echo "$(date +%T) FRAC $f: $r(end $(temp)C)"
  awk -v a="$tg" -v b="$bt" 'BEGIN{exit !(a>b)}' && { bt=$tg; best=$f; }
done
echo "best for generation: FRAC $best ($bt tok/s)"
