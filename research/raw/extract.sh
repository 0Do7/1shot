#!/bin/bash
# Usage: extract.sh file.json [submission|comment]
F=$1; T=$2
if [ "$T" = "submission" ]; then
  jq -r '.data[] | "DATE: \(.created_utc|floor|todate) | r/\(.subreddit) | score:\(.score) | u/\(.author)\nURL: https://reddit.com\(.permalink // ("/comments/"+.id))\nTITLE: \(.title)\nBODY: \((.selftext // "")[0:1500])\n====="' "$F"
else
  jq -r '.data[] | "DATE: \(.created_utc|floor|todate) | r/\(.subreddit) | score:\(.score) | u/\(.author)\nURL: https://reddit.com\(.permalink // ("/comments/"+(.link_id|sub("t3_";""))+"//"+.id))\nBODY: \((.body // "")[0:1500])\n====="' "$F"
fi
