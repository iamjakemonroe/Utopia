#!/bin/zsh
# What players send from "Report a bug" and "Suggest a feature", for
# working through them: read the new ones, fix or build what's worth it,
# then mark each one so the player sees what happened to it.
#
#   tool/reports.sh                       new reports, oldest first
#   tool/reports.sh all                   every report
#   tool/reports.sh shot <id> [dir]       download its screenshot (to build/report-shots)
#   tool/reports.sh mark <id> <status> [note]
#       status: triaged (seen, on the list), fixed (done), wontfix
#       note:   shown to the player under their report ("Fixed in 1.0.0+15")
#
# The project's secret key is fetched from the Supabase CLI each run and
# only ever held in memory: it's never printed or written anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

REF=$(cat supabase/.temp/project-ref)
URL=$(python3 -c "import json;print(json.load(open('env/local.json'))['SUPABASE_URL'])")
KEY=$(supabase projects api-keys --project-ref "$REF" --reveal -o json 2>/dev/null |
  python3 -c "import json,sys;print(next(k['api_key'] for k in json.load(sys.stdin) if k.get('type')=='secret'))")

# Prints reports readably: kind, status, when, who; build and phone; text.
FORMAT=$(cat <<'PY'
import json, sys
rows = json.load(sys.stdin)
if isinstance(rows, dict):
    sys.exit('error: ' + json.dumps(rows))
if not rows:
    print('No reports.')
for r in rows:
    who = r.get('profiles') or {}
    name = who.get('username') or who.get('display_name') or 'guest'
    when = r['created_at'][:16].replace('T', ' ')
    print('-' * 72)
    print('%-9s %-8s %s  @%s' % (r['category'].upper(), r['status'], when, name))
    print('id ' + r['id'])
    bits = [b for b in (r.get('app_version'), r.get('platform'), r.get('screen'), r.get('world')) if b]
    if bits:
        print(' / '.join(bits))
    if r.get('screenshot_path'):
        print('screenshot: tool/reports.sh shot ' + r['id'])
    if r.get('contact'):
        print('contact: ' + r['contact'])
    print()
    print(r['description'])
    if r.get('resolution'):
        print()
        print('-> ' + r['resolution'])
print('-' * 72)
print('%d report(s)' % len(rows))
PY
)

rest() {
  curl -sS -H "apikey: $KEY" -H "Content-Type: application/json" "$@"
}

case "${1:-new}" in
  new | all)
    filter='&status=eq.new'
    [[ "${1:-new}" == all ]] && filter=''
    rest "$URL/rest/v1/bug_reports?select=*,profiles(username,display_name)&order=created_at.asc$filter" |
      python3 -c "$FORMAT"
    ;;
  shot)
    id=${2:?id}; dest=${3:-build/report-shots}
    path=$(rest "$URL/rest/v1/bug_reports?select=screenshot_path&id=eq.$id" |
      python3 -c 'import json,sys;r=json.load(sys.stdin);print((r[0].get("screenshot_path") or "") if isinstance(r,list) and r else "")')
    [[ -z "$path" ]] && { echo "No screenshot on that report."; exit 1; }
    mkdir -p "$dest"
    out="$dest/$id.${path##*.}"
    curl -sS -f -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
      "$URL/storage/v1/object/bug-screenshots/$path" -o "$out"
    echo "$out"
    ;;
  mark)
    id=${2:?id}; st=${3:?status}; note=${4:-}
    [[ "$st" == (new|triaged|fixed|wontfix) ]] ||
      { echo "status must be new, triaged, fixed or wontfix"; exit 1; }
    body=$(python3 -c 'import json,sys;d={"status":sys.argv[1]};n=sys.argv[2]
if n: d["resolution"]=n
print(json.dumps(d))' "$st" "$note")
    rest -X PATCH "$URL/rest/v1/bug_reports?id=eq.$id" -H "Prefer: return=representation" -d "$body" |
      python3 -c 'import json,sys;r=json.load(sys.stdin);print("marked", r[0]["status"] if isinstance(r,list) and r else r)'
    ;;
  *)
    sed -n 2,14p "$0"
    exit 1
    ;;
esac
