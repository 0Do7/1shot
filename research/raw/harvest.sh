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
for id in 1iu8s5o 1j87ewh 1iaysxg 1kdcjl3 1h1oyuz 1h1ouzp 1go4d6b 1fzaomz 1fzag7u 1ga3ngv 1jtpoow 1jrelxg 1ivcmw8 1km688x 1jxlau1 1kf42jc 1k9af1c 1hwpg6w 1fspwli 1fxiga8 1inxvml 1bvo3ms 1h1p1qi 1fssvlt 1bavykp; do
  h $id; sleep 4
done
echo HARVEST1_DONE
