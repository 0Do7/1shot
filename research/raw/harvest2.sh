#!/bin/bash
DIR=/Users/codyhung/Sidequests/screenshot/research/raw
h() {
  [ -s "$DIR/th_$1.json" ] && jq -e '.data' "$DIR/th_$1.json" >/dev/null 2>&1 && { echo "SKIP $1"; return; }
  for i in 1 2 3; do
    curl -s -m 90 "https://api.pullpush.io/reddit/search/comment/?link_id=$1&size=100" -o "$DIR/th_$1.json"
    if jq -e '.data and (.data|type=="array")' "$DIR/th_$1.json" >/dev/null 2>&1; then
      echo "OK $1 $(jq '.data|length' "$DIR/th_$1.json")"; return
    fi
    sleep 6
  done
  echo "FAIL $1"
}
for id in 1ffl2sv 1hs5fm6 1fl14r3 1c2rdoj 1gccpa7 1j9j750 1f8nm8b 1hl3cmh 1h4vz85 1g1r99c 1iob1vr 1ipbr0j; do
  h $id; sleep 4
done
echo HARVEST2_DONE
