#!/usr/bin/env bash
# Tests for the nonlocally plugin's scripts. Run from anywhere: tests/run.sh
# Every test gets a fresh HOME, so no real key is ever read or written.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLUGIN="$ROOT/plugins/nonlocally"
HEADERS="$PLUGIN/bin/market-headers"
SAVE="$PLUGIN/skills/market/scripts/save-market-key"
API="$PLUGIN/skills/market/scripts/market-api"
KEY="bnty_abcdefghijkl_abcdefghijklmnopqrstuvwxyz234567abcdefgh"
passed=0
failed=0

check() { # label, then a command that must succeed
  local label=$1
  shift
  if "$@"; then
    passed=$((passed + 1))
    echo "PASS $label"
  else
    failed=$((failed + 1))
    echo "FAIL $label"
  fi
}

fresh_home() {
  T=$(mktemp -d)
  export HOME="$T/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME
}

key_file() { echo "${XDG_CONFIG_HOME:-$HOME/.config}/nonlocally/market-key"; }

put_key() { # write a key file the way save-market-key would
  mkdir -p "$(dirname "$(key_file)")"
  printf '%s\n' "$1" >"$(key_file)"
  chmod 600 "$(key_file)"
}

# ── market-headers: what the MCP server sends ────────────────────────────────────────────────

fresh_home
out=$("$HEADERS" 2>"$T/err")
status=$?
check "headers: no key file fails" test "$status" -ne 0
check "headers: no key file prints nothing" test -z "$out"
check "headers: no key file says where to get one" grep -q "research.nonlocally.org/keys" "$T/err"
check "headers: no key file names the path" grep -q "nonlocally/market-key" "$T/err"

fresh_home
put_key "not-a-key"
out=$("$HEADERS" 2>"$T/err")
status=$?
check "headers: malformed key fails" test "$status" -ne 0
check "headers: malformed key is not echoed" bash -c "! grep -q not-a-key '$T/err'"

fresh_home
printf '%s\r\n\n' "$KEY" >"$T/raw"
put_key "$(cat "$T/raw")"
out=$("$HEADERS")
check "headers: prints the Authorization header as JSON" \
  test "$out" = "{\"Authorization\":\"Bearer $KEY\"}"
check "headers: output is valid JSON" python3 -c 'import json,sys; json.loads(sys.argv[1])' "$out"

fresh_home
export XDG_CONFIG_HOME="$T/xdg"
put_key "$KEY"
check "headers: honours XDG_CONFIG_HOME" test "$("$HEADERS")" = "{\"Authorization\":\"Bearer $KEY\"}"
unset XDG_CONFIG_HOME

# ── save-market-key: how a person stores their key ────────────────────────────────────────────

fresh_home
out=$(printf '  %s  \n' "$KEY" | "$SAVE" 2>&1)
status=$?
check "save: succeeds" test "$status" -eq 0
check "save: writes exactly the key" test "$(cat "$(key_file)")" = "$KEY"
check "save: file is private (600)" test "$(stat -f %Lp "$(key_file)" 2>/dev/null || stat -c %a "$(key_file)")" = 600
check "save: folder is private (700)" test "$(stat -f %Lp "$(dirname "$(key_file)")" 2>/dev/null || stat -c %a "$(dirname "$(key_file)")")" = 700
check "save: never prints the key" bash -c "! grep -q '$KEY' <<<'$out'"
check "save: says where it saved" grep -q "nonlocally/market-key" <<<"$out"

out=$(printf '%s\n' "${KEY/a/b}" | "$SAVE" 2>&1)
status=$?
check "save: refuses to replace an existing key" test "$status" -ne 0
check "save: existing key unchanged" test "$(cat "$(key_file)")" = "$KEY"
printf '%s\n' "${KEY/a/b}" | "$SAVE" --replace >/dev/null 2>&1
check "save: --replace replaces it" test "$(cat "$(key_file)")" = "${KEY/a/b}"

fresh_home
printf 'hello\n' | "$SAVE" >/dev/null 2>"$T/err"
status=$?
check "save: refuses something that is not a key" test "$status" -ne 0
check "save: writes nothing for a bad key" test ! -e "$(key_file)"
check "save: does not echo the bad input" bash -c "! grep -q hello '$T/err'"

# ── market-api: REST calls for what MCP does not cover ───────────────────────────────────────

fresh_home
out=$("$API" GET /v1/me 2>"$T/err")
status=$?
check "api: no key file fails" test "$status" -ne 0
check "api: no key file says where to get one" grep -q "research.nonlocally.org/keys" "$T/err"

fresh_home
put_key "$KEY"
python3 "$ROOT/tests/mock_market.py" "$T/port" "$T/log" &
mock=$!
trap 'kill $mock 2>/dev/null' EXIT
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
export NONLOCALLY_MARKET_URL="http://127.0.0.1:$(cat "$T/port")"

out=$("$API" GET /v1/me)
check "api: GET prints the response" test "$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["handle"])' "$out")" = ada
last() { tail -1 "$T/log" | python3 -c "import json,sys; r=json.load(sys.stdin); print($1)"; }
check "api: sends the key as a bearer token" test "$(last 'r["headers"]["authorization"]')" = "Bearer $KEY"
check "api: names its client" bash -c "[[ '$(last 'r["headers"]["user-agent"]')' == nonlocally-plugin/* ]]"
check "api: GET sends no idempotency key" test "$(last 'r["headers"].get("idempotency-key", "")')" = ""

"$API" POST /v1/admin/mint '{"account_id":"ac_x","amount":5,"memo":"t"}' >/dev/null 2>"$T/err"
check "api: POST forwards the JSON body" test "$(last 'r["body"]')" = '{"account_id":"ac_x","amount":5,"memo":"t"}'
check "api: POST sends JSON" test "$(last 'r["headers"]["content-type"]')" = application/json
idem=$(last 'r["headers"].get("idempotency-key", "")')
check "api: POST gets a fresh idempotency key" python3 -c 'import uuid,sys; uuid.UUID(sys.argv[1])' "$idem"
check "api: POST reports its idempotency key for retries" grep -q "$idem" "$T/err"

MARKET_IDEMPOTENCY_KEY=retry-1 "$API" POST /v1/contracts '{}' >/dev/null 2>&1
check "api: a retry reuses the given idempotency key" test "$(last 'r["headers"]["idempotency-key"]')" = retry-1

printf '{"title":"from a file"}' >"$T/body.json"
"$API" POST /v1/contracts "@$T/body.json" >/dev/null 2>&1
check "api: @file sends the file as the body" test "$(last 'r["body"]')" = '{"title":"from a file"}'

out=$("$API" GET /v1/missing 2>/dev/null)
status=$?
check "api: an error status fails" test "$status" -ne 0
check "api: an error still shows the market's message" grep -q not_found <<<"$out"

out=$("$API" GET /v1/me 2>&1 >/dev/null; "$API" POST /v1/contracts '{}' 2>&1 >/dev/null)
check "api: never prints the key" bash -c "! grep -q '$KEY' <<<'$out'"

"$API" GET me >/dev/null 2>&1
check "api: refuses a path that is not under /v1/" test $? -ne 0

echo
echo "passed=$passed failed=$failed"
[ "$failed" -eq 0 ]
