#!/usr/bin/env bash
#
# Re-provision the roostos.dev apex custom domain on the roostos-web Worker.
# If Cloudflare registered the custom domain but never created its DNS record
# (a common apex glitch), deleting + re-attaching it forces a clean provision.
#
# Auth: uses $CLOUDFLARE_API_TOKEN if set, else falls back to wrangler's stored
# OAuth login (~/Library/Preferences/.wrangler/config/default.toml) — which has
# workers_routes:write, enough to manage custom domains.
#
#   ./fix-apex.sh
#
set -euo pipefail

DOMAIN="roostos.dev"
SERVICE="roostos-web"
ACCT="d8f2b80b4b6f160190e4e62faded6950"
API="https://api.cloudflare.com/client/v4"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

TOKEN="${CLOUDFLARE_API_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  WC="$HOME/Library/Preferences/.wrangler/config/default.toml"
  [ -f "$WC" ] && TOKEN=$(grep '^oauth_token' "$WC" | sed -E 's/.*"([^"]+)".*/\1/')
fi
[ -n "$TOKEN" ] || { echo "No token. Run 'wrangler login' or export CLOUDFLARE_API_TOKEN."; exit 1; }
AUTH="Authorization: Bearer $TOKEN"
cf(){ curl -s -H "$AUTH" -H "Content-Type: application/json" "$@"; }
ok(){ python3 -c 'import json,sys;print("ok" if json.load(open(sys.argv[1])).get("success") else "FAILED: "+json.dumps(json.load(open(sys.argv[1])).get("errors")))' "$1"; }

echo "==> zone id for $DOMAIN"
cf "$API/zones?name=$DOMAIN" -o "$TMP/z.json"
ZID=$(python3 -c 'import json,sys;r=json.load(open(sys.argv[1])).get("result") or [];print(r[0]["id"] if r else "")' "$TMP/z.json")
[ -n "$ZID" ] || { echo "   couldn't read zone (token lacks zone:read). Use the dashboard."; exit 1; }
echo "   $ZID"

echo "==> current apex custom-domain binding"
cf "$API/accounts/$ACCT/workers/domains" -o "$TMP/wd.json"
DID=$(python3 -c 'import json,sys;print(next((x["id"] for x in (json.load(open(sys.argv[1])).get("result") or []) if x.get("hostname")=="'"$DOMAIN"'"),""))' "$TMP/wd.json")
if [ -n "$DID" ]; then
  echo "   deleting $DID"
  cf -X DELETE "$API/accounts/$ACCT/workers/domains/$DID" -o "$TMP/del.json" || true
fi

echo "==> re-attaching $DOMAIN -> $SERVICE (forces fresh DNS provisioning)"
cf -X PUT "$API/accounts/$ACCT/workers/domains" \
   -d "{\"zone_id\":\"$ZID\",\"hostname\":\"$DOMAIN\",\"service\":\"$SERVICE\",\"environment\":\"production\"}" -o "$TMP/put.json"
echo -n "   attach: "; ok "$TMP/put.json"

echo "==> waiting for DNS + edge cert (Cloudflare issues the cert; can take a few min)"
for i in $(seq 1 18); do
  sleep 10
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "https://$DOMAIN" 2>/dev/null || echo 000)
  echo "   [$((i*10))s] https://$DOMAIN -> $code"
  [ "$code" = "200" ] && { echo "==> live! (clear Edge DNS cache: edge://net-internals/#dns)"; exit 0; }
done
echo "==> DNS is set; edge cert still provisioning — re-check https://$DOMAIN in a few minutes."
