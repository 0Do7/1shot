#!/bin/bash
DIR=/Users/codyhung/Sidequests/screenshot/research/raw
AFTER=1704067200   # 2024-01-01
fetch() {  # $1=type(submission|comment) $2=name $3=query $4=subreddit(optional) $5=after(optional)
  local url="https://api.pullpush.io/reddit/search/$1/?q=$3&size=100&sort=desc&sort_type=created_utc"
  [ -n "$4" ] && url="$url&subreddit=$4"
  [ -n "$5" ] && url="$url&after=$5"
  for i in 1 2 3; do
    curl -s -m 60 "$url" -o "$DIR/$2.json"
    if jq -e '.data' "$DIR/$2.json" >/dev/null 2>&1; then
      echo "OK $2 $(jq '.data|length' "$DIR/$2.json")"
      return
    fi
    sleep 10
  done
  echo "FAIL $2"
}

# unrestricted, 2024+
fetch submission sub_cleanshot_2024 "cleanshot" "" $AFTER; sleep 4
fetch comment   com_cleanshot_2024 "cleanshot" "" $AFTER; sleep 4
fetch submission sub_shottr_2024 "shottr" "" $AFTER; sleep 4
fetch comment   com_shottr_2024 "shottr" "" $AFTER; sleep 4
fetch comment   com_cleanshot_vs "%22cleanshot%20vs%22" "" ; sleep 4
fetch submission sub_cleanshot_vs "%22cleanshot%20vs%22" "" ; sleep 4
fetch comment   com_shottr_vs "%22shottr%20vs%22" "" ; sleep 4
fetch submission sub_shottr_vs "%22shottr%20vs%22" "" ; sleep 4
fetch submission sub_screenshot_app_mac "screenshot%20app%20mac" "" $AFTER; sleep 4
fetch comment   com_cleanshot_alt "cleanshot%20alternative" "" ; sleep 4
fetch submission sub_cleanshot_alt "cleanshot%20alternative" "" ; sleep 4
fetch comment   com_shottr_alt "shottr%20alternative" "" ; sleep 4
# subreddit-restricted
fetch comment com_cleanshot_macapps "cleanshot" "macapps" $AFTER; sleep 4
fetch comment com_shottr_macapps "shottr" "macapps" $AFTER; sleep 4
fetch comment com_cleanshot_macos "cleanshot" "MacOS" $AFTER; sleep 4
fetch comment com_shottr_macos "shottr" "MacOS" $AFTER; sleep 4
fetch comment com_cleanshot_mac "cleanshot" "mac" $AFTER; sleep 4
fetch comment com_shottr_mac "shottr" "mac" $AFTER; sleep 4
fetch submission sub_cleanshot_macapps "cleanshot" "macapps" $AFTER; sleep 4
fetch submission sub_shottr_macapps "shottr" "macapps" $AFTER; sleep 4
# other tools
fetch comment com_xnapper "xnapper" "" $AFTER; sleep 4
fetch comment com_cleanshot_pricing "cleanshot%20price" "" ; sleep 4
fetch comment com_cleanshot_sub "cleanshot%20subscription" "" ; sleep 4
fetch comment com_snagit_mac "snagit%20mac" "" $AFTER; sleep 4
# older slices for cleanshot/shottr comments (pre-2024 capped at 100 newest anyway, get 2024 H1 via before)
fetch comment com_cleanshot_2024H1 "cleanshot" "" "" ; sleep 4
echo DONE
