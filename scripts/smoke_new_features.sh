#!/bin/bash
# Smoke-test new labour/diary/plans/work APIs against production.
set -euo pipefail
BASE="${BASE_URL:-https://agrazllp.com/api}"
SUFFIX=$(date +%s | tail -c 6)
PHONE="99900$SUFFIX"
PASS="TestPass123!"
EMAIL="smoke${SUFFIX}@example.com"

echo "== Register $PHONE"
REG=$(curl -sS -X POST "$BASE/mobile/register" \
  -H 'Content-Type: application/json' \
  -d "{\"firstname\":\"Smoke\",\"lastname\":\"Test\",\"email\":\"$EMAIL\",\"phone\":\"$PHONE\",\"password\":\"$PASS\",\"confirmPassword\":\"$PASS\"}")
echo "$REG" | head -c 300; echo

echo "== Login"
LOGIN=$(curl -sS -X POST "$BASE/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
TOKEN=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("token") or d.get("access_token") or (d.get("data") or {}).get("token") or "")' "$LOGIN")
if [[ -z "$TOKEN" ]]; then
  LOGIN=$(curl -sS -X POST "$BASE/login" \
    -H 'Content-Type: application/json' \
    -d "{\"mobile\":\"$PHONE\",\"password\":\"$PASS\"}")
  TOKEN=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("token") or d.get("access_token") or (d.get("data") or {}).get("token") or "")' "$LOGIN")
fi
if [[ -z "$TOKEN" ]]; then
  echo "FAIL: no token. login=$LOGIN"
  exit 1
fi
AUTH="Authorization: Bearer $TOKEN"
echo "Got token (${#TOKEN} chars)"

echo "== Diary label CRUD"
L=$(curl -sS -X POST "$BASE/diary/labels" -H "$AUTH" -H 'Content-Type: application/json' -d '{"name":"Amount","icon":"money"}')
echo "$L"
LID=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print((d.get("data") or {}).get("id") or "")' "$L")
test -n "$LID"
curl -sS -X PUT "$BASE/diary/labels/$LID" -H "$AUTH" -H 'Content-Type: application/json' -d '{"name":"Amount/Days","icon":"money"}' >/dev/null
curl -sS "$BASE/diary/labels" -H "$AUTH" | head -c 180; echo

echo "== Diary entry CRUD"
E=$(curl -sS -X POST "$BASE/diary/entries" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"content\":\"Smoke note\",\"label_id\":$LID,\"date\":\"2026-08-16\",\"amount\":100,\"num_days\":2}")
echo "$E" | head -c 220; echo
EID=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print((d.get("data") or {}).get("id") or "")' "$E")
test -n "$EID"
curl -sS -X PUT "$BASE/diary/entries/$EID" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"content\":\"Smoke note updated\",\"label_id\":$LID,\"date\":\"2026-08-16\"}" >/dev/null
curl -sS "$BASE/diary/entries?q=Smoke" -H "$AUTH" | head -c 180; echo
curl -sS -X DELETE "$BASE/diary/entries/$EID" -H "$AUTH" >/dev/null
curl -sS -X DELETE "$BASE/diary/labels/$LID" -H "$AUTH" >/dev/null

echo "== Future plan CRUD"
P=$(curl -sS -X POST "$BASE/future_plans" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"plan_name":"Rainwater","entry_date":"2026-08-16","plan_year":2026,"plan_month":8,"lines":[{"description":"Tank","estimate_cost":50000},{"description":"Pipes","estimate_cost":8000}]}')
echo "$P" | head -c 220; echo
PID=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print((d.get("data") or {}).get("id") or "")' "$P")
test -n "$PID"
curl -sS -X PUT "$BASE/future_plans/$PID" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"status":"in_progress","actual_cost":12000,"end_date":"2026-12-31"}' >/dev/null
curl -sS "$BASE/future_plans/$PID" -H "$AUTH" | head -c 200; echo
curl -sS -X DELETE "$BASE/future_plans/$PID" -H "$AUTH" >/dev/null

echo "== Labour payable + extras + tally + bulk rate"
LAB=$(curl -sS -X POST "$BASE/labors" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"Smoke Labour","wage":500,"hours":1,"shift":"fullday","category":"Plucking","gender":"Male","work_type":"Daily Wages","location":"Farm","narration":"test","date":"2026-08-16","entry_kind":"payable","rent":50,"food":20,"bonus":10}')
echo "$LAB" | head -c 280; echo
LABID=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print((d.get("data") or {}).get("id") or "")' "$LAB")
test -n "$LABID"
T=$(curl -sS -X POST "$BASE/labors" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"Smoke Labour","wage":0,"hours":1,"entry_kind":"tally","category":"Tally","gender":"Male","work_type":"Daily Wages","location":"Farm","narration":"Tally till Aug","date":"2026-08-16"}')
echo "$T" | head -c 200; echo
BR=$(curl -sS -X PUT "$BASE/labors/bulk-rate" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"Smoke Labour","from":"2026-01-01","to":"2026-12-31","rate":550}')
echo "$BR"
curl -sS -X DELETE "$BASE/labors/$LABID" -H "$AUTH" >/dev/null

echo "== Labour work entry CRUD"
W=$(curl -sS -X POST "$BASE/labor_works" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"Self","wage":400,"hours":1,"shift":"fullday","category":"Plucking","gender":"Male","work_type":"Daily Wages","location":"Farm","narration":"my work","date":"2026-08-16","entry_kind":"receivable"}')
echo "$W" | head -c 200; echo
WID=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print((d.get("data") or {}).get("id") or "")' "$W")
test -n "$WID"
curl -sS "$BASE/labor_works/reports" -H "$AUTH" | head -c 200; echo
curl -sS -X DELETE "$BASE/labor_works/$WID" -H "$AUTH" >/dev/null

echo "ALL CRUD CHECKS DONE OK"
