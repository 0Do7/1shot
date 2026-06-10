#!/bin/bash
DIR=/Users/codyhung/Sidequests/screenshot/research/raw
A24=1704067200   # 2024-01-01
B25=1735689600   # 2025-01-01
f() { # $1 name $2 query $3 sub $4 after $5 before
  local url="https://api.pullpush.io/reddit/search/submission/?q=$2&size=100&sort=desc&sort_type=created_utc"
  [ -n "$3" ] && url="$url&subreddit=$3"
  [ -n "$4" ] && url="$url&after=$4"
  [ -n "$5" ] && url="$url&before=$5"
  for i in 1 2; do
    curl -s -m 100 "$url" -o "$DIR/$1.json"
    if jq -e '.data and (.data|type=="array")' "$DIR/$1.json" >/dev/null 2>&1; then
      echo "OK $1 $(jq '.data|length' "$DIR/$1.json")"; return
    fi
    sleep 8
  done
  echo "FAIL $1"
}
f sub_shottr_2025 "shottr" "" $B25 ""; sleep 3
f sub_shottr_2024 "shottr" "" $A24 $B25; sleep 3
f sub_cleanshot_2024only "cleanshot" "" $A24 $B25; sleep 3
f sub_cleanshot_macapps "cleanshot" "macapps" $A24 ""; sleep 3
f sub_shottr_macapps "shottr" "macapps" $A24 ""; sleep 3
f sub_cleanshot_macos "cleanshot" "MacOS" $A24 ""; sleep 3
f sub_shottr_macos "shottr" "MacOS" $A24 ""; sleep 3
f sub_cs_vs "%22cleanshot+vs%22" "" "" ""; sleep 3
f sub_sh_vs "%22shottr+vs%22" "" "" ""; sleep 3
f sub_cs_alt "cleanshot+alternative" "" "" ""; sleep 3
f sub_sh_alt "shottr+alternative" "" "" ""; sleep 3
f sub_ss_app_macapps "screenshot" "macapps" $A24 ""; sleep 3
f sub_ss_app_macos "screenshot+app" "MacOS" $A24 ""; sleep 3
f sub_xnapper "xnapper" "" "" ""; sleep 3
f sub_cs_worth "cleanshot+worth" "" "" ""; sleep 3
echo DONE
