#!/usr/bin/env bash
#
# Fix the roostos.dev apex custom domain on the roostos-web Worker.
# Cloudflare registered the custom domain but couldn't create the apex DNS
# record (usually a stray/conflicting root record). This finds it, removes it
# (with your OK), and attaches the apex to the Worker.
#
# Needs CLOUDFLARE_API_TOKEN in your env with: Zone:Read+Edit, Workers Routes:Edit.
#   ./fix-apex.sh          # diagnose + prompt before changing anything
#   ./fix-apex.sh --yes    # do it without prompting
#
set -euo pipefail

DOMAIN="roostos.dev"
SERVICE="roostos-web"
ACCT="d8f2b80b4b6f160190e4e62faded6950"
API="https://api.cloudflare.com/client/v4"
YES="${1:-}"

: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN first (your interactive shell should have it)}"
AUTH="Authorization: Bearer $CLOUDFLARE_API_TOKEN"
cf(){ curl -s -H "$AUTH" -H "Content-Type: application/json" "$@"; }

echo "==> verifying token"
cf "$API/user/tokens/verify" | python3 -c '
import sys,json; d=json.load(sys.stdin)
print("   token:", "valid" if d.get("success") else "INVALID -> "+json.dumps(d.get("errors")))
sys.exit(0 if d.get("success") else 1)'

echo "==> looking up zone for $DOMAIN"
ZRESP=$(cf "$API/zones?name=$DOMAIN")
ZID=$(printf '%s' "$ZRESP" | python3 -c 'import sys,json; r=(json.load(sys.stdin).get("result") or []); print(r[0]["id"] if r else "")')
if [ -z "$ZID" ]; then
  echo "   couldn't read the zone. Raw response:"
  printf '%s' "$ZRESP" | python3 -m json.tool | sed 's/^/     /'
  echo "   -> your token lacks Zone:Read. Fix it in the dashboard, or make a token with Zone:Read+Edit + Workers Routes:Edit."
  exit 1
fi
echo "   zone: $ZID"

echo "==> apex records at $DOMAIN"
RECS=$(cf "$API/zones/$ZID/dns_records?name=$DOMAIN")
printf '%s' "$RECS" | python3 -c '
import sys,json
r=json.load(sys.stdin).get("result") or []
print("\n".join(f"     {x[\"type\"]:6} {x[\"name\"]} -> {x.get(\"content\")}  (proxied={x.get(\"proxied\")}, id={x[\"id\"]})" for x in r) or "     (none)")'

# conflicting root records = A/AAAA/CNAME at the apex (a Worker custom domain owns the apex itself)
CONFLICTS=$(printf '%s' "$RECS" | python3 -c 'import sys,json;[print(x["id"]) for x in (json.load(sys.stdin).get("result") or []) if x["type"] in ("A","AAAA","CNAME")]')

if [ -n "$CONFLICTS" ]; then
  echo "==> these root records conflict with the custom domain and must be removed:"
  echo "$CONFLICTS" | sed 's/^/     id /'
  if [ "$YES" != "--yes" ]; then
    printf "   delete them and attach %s to the Worker? [y/N] " "$DOMAIN"; read -r ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "   aborted."; exit 0; }
  fi
  for id in $CONFLICTS; do
    cf -X DELETE "$API/zones/$ZID/dns_records/$id" >/dev/null && echo "   deleted $id"
  done
fi

echo "==> attaching $DOMAIN as a custom domain on Worker '$SERVICE'"
cf -X PUT "$API/accounts/$ACCT/workers/domains" \
   -d "{\"zone_id\":\"$ZID\",\"hostname\":\"$DOMAIN\",\"service\":\"$SERVICE\",\"environment\":\"production\"}" \
 | python3 -c '
import sys,json; d=json.load(sys.stdin)
print("   ", "attached ✅" if d.get("success") else "FAILED -> "+json.dumps(d.get("errors")))'

echo
echo "==> give it ~1 min, then verify:"
echo "     dig +short $DOMAIN @1.1.1.1"
echo "     curl -sI https://$DOMAIN | head -1"
echo "   (in Edge, clear its DNS cache: edge://net-internals/#dns -> Clear host cache)"
