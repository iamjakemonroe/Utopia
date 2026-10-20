#!/bin/zsh
# What players send from "Report a bug" and "Suggest a feature", for
# working through them: read the new ones, fix or build what's worth it,
# then mark each one so the player sees what happened to it.
#
#   tool/reports.sh                       new reports, oldest first
#   tool/reports.sh all                   every report
#   tool/reports.sh shot <id> [dir]       download its screenshot (to build/report-shots)
#   tool/reports.sh links                 give older reports' screenshots a link (a year)
#   tool/reports.sh mark <id> <status> [note]
#       status: triaged (seen, on the list), fixed (done), wontfix
#       note:   shown to the player under their report ("Fixed in 1.0.0+15")
#       Marked fixed or wontfix, the player also gets a notification (from
#       Chip) with the note, so mark with the note in the same go.
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
    if r.get('screenshot_url'):
        print('screenshot: ' + r['screenshot_url'])
    elif r.get('screenshot_path'):
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
    # (Not "path": in zsh that's the PATH itself.)
    file=$(rest "$URL/rest/v1/bug_reports?select=screenshot_path&id=eq.$id" |
      python3 -c 'import json,sys;r=json.load(sys.stdin);print((r[0].get("screenshot_path") or "") if isinstance(r,list) and r else "")')
    [[ -z "$file" ]] && { echo "No screenshot on that report."; exit 1; }
    mkdir -p "$dest"
    out="$dest/$id.${file##*.}"
    curl -sS -f -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
      "$URL/storage/v1/object/bug-screenshots/$file" -o "$out"
    echo "$out"
    ;;
  links)
    # Screenshots sent before the app asked for links (or when that
    # failed): a signed link each, good for a year, on the report.
    rest "$URL/rest/v1/bug_reports?select=id,screenshot_path&screenshot_path=not.is.null&screenshot_url=is.null" |
      python3 -c 'import json,sys
for r in json.load(sys.stdin): print(r["id"], r["screenshot_path"])' |
      while read -r id file; do
        signed=$(curl -sS -f -X POST -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
          -H "Content-Type: application/json" -d '{"expiresIn": 31536000}' \
          "$URL/storage/v1/object/sign/bug-screenshots/$file" |
          python3 -c 'import json,sys;print(json.load(sys.stdin).get("signedURL",""))')
        [[ -z "$signed" ]] && { echo "couldn't sign $id"; continue; }
        body=$(python3 -c 'import json,sys;print(json.dumps({"screenshot_url":sys.argv[1]}))' "$URL/storage/v1$signed")
        rest -X PATCH "$URL/rest/v1/bug_reports?id=eq.$id" -d "$body" >/dev/null && echo "linked $id"
      done
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
    sed -n 2,15p "$0"
    exit 1
    ;;
esac
