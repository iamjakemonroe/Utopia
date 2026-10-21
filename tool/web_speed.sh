#!/bin/zsh
# How smoothly the web game runs for players, from what it records (see
# lib/core/widgets/web_frame_watch.dart): frames a second on each screen
# (web_fps), and freezes (web_freeze, web_stall), worst screens first.
#
#   tool/web_speed.sh [days]      the last [days] days (7 by default)
#
# The project's secret key is fetched from the Supabase CLI each run and
# only ever held in memory: it's never printed or written anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

DAYS=${1:-7}
REF=$(cat supabase/.temp/project-ref)
URL=$(python3 -c "import json;print(json.load(open('env/local.json'))['SUPABASE_URL'])")
KEY=$(supabase projects api-keys --project-ref "$REF" --reveal -o json 2>/dev/null |
  python3 -c "import json,sys;print(next(k['api_key'] for k in json.load(sys.stdin) if k.get('type')=='secret'))")
SINCE=$(python3 -c "import datetime;print((datetime.datetime.utcnow()-datetime.timedelta(days=$DAYS)).isoformat())")

REPORT=$(cat <<'PY'
import json, sys, statistics
from collections import defaultdict
rows = json.load(sys.stdin)
if isinstance(rows, dict):
    sys.exit("error: " + json.dumps(rows))
fps = defaultdict(list)
freezes = defaultdict(list)
players = set()
for r in rows:
    p = r["props"] or {}
    players.add(r["user_id"])
    path = p.get("path", "?")
    if r["name"] == "web_fps" and p.get("fps"):
        fps[path].append(p["fps"])
    elif r["name"] in ("web_freeze", "web_stall"):
        freezes[path].append((r["name"], p))
print("%d events from %d players" % (len(rows), len(players)))
print("\nframes a second, slowest screens first (median, worst tenth, visits):")
for path, v in sorted(fps.items(), key=lambda kv: statistics.median(kv[1])):
    v = sorted(v)
    print("  %5.0f  %5.0f  %4d  %s" % (statistics.median(v), v[len(v)//10], len(v), path))
print("\nfreezes by screen (count, median ms, worst ms, how many as the screen opened):")
for path, v in sorted(freezes.items(), key=lambda kv: -len(kv[1])):
    ms = sorted(p.get("ms", 0) for _, p in v)
    opening = sum(1 for _, p in v if (p.get("open_s") or 0) <= 2)
    print("  %4d  %5d  %5d  %4d  %s" % (len(v), ms[len(ms)//2], ms[-1], opening, path))
PY
)

curl -sS -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  "$URL/rest/v1/app_events?select=name,props,at,user_id&name=in.(web_fps,web_freeze,web_stall)&at=gte.$SINCE&order=at.desc&limit=20000" |
  python3 -c "$REPORT"
