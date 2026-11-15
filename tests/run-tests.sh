#!/usr/bin/env bash
# Runs the hook the way Claude Code does: hook JSON on stdin, decision JSON on stdout.
# Needs jq (for building and reading test JSON only; the plugin itself doesn't use it).
# Usage: tests/run-tests.sh            (uses the default awk)
#        PII_CHECK_AWK=gawk tests/run-tests.sh

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/scripts/check-prompt.sh"
export TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
PASS=0; FAIL=0
SESSION="test-$$"

run() {  # run <prompt> -> prints hook stdout
    printf '%s' "$1" | jq -Rs --arg s "$SESSION" \
      '{session_id:$s, transcript_path:"/tmp/x/00893aaf-19fa-41d2-8238-13269b9b3ca0.jsonl", cwd:"/tmp", permission_mode:"default", hook_event_name:"UserPromptSubmit", prompt:.}' \
      | bash "$HOOK"
}

ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n%s\n' "$1" "$2" | sed 's/^/        /;1s/^        //'; }

expect_block() {  # expect_block <name> <prompt> <text the reason must contain>...
    local name=$1 prompt=$2; shift 2
    local out; out="$(run "$prompt")"
    local reason; reason="$(printf '%s' "$out" | jq -r 'select(.decision=="block") | .reason' 2>/dev/null)"
    [ -n "$reason" ] || { bad "$name" "expected a block, got: ${out:-<nothing>}"; return; }
    local want
    for want in "$@"; do
        case "$reason" in *"$want"*) ;; *) bad "$name" "reason is missing \"$want\":
$reason"; return;; esac
    done
    ok "$name"
}

expect_pass() {  # expect_pass <name> <prompt>
    local out; out="$(run "$2")"
    [ -z "$out" ] && ok "$1" || bad "$1" "expected no output, got: $out"
}

new_session() { SESSION="test-$$-$RANDOM"; }

echo "Emails"
new_session; expect_block "plain email" "contact j.ortiz@acme.com please" "email: j.ortiz@acme.com"
new_session; expect_block "email after a newline" $'see below\nj.ortiz@acme.com' "email: j.ortiz@acme.com"
new_session; expect_block "email in quotes" 'user="maya+test@mail.example.co.uk"' "email: maya+test@mail.example.co.uk"

echo "Phone numbers"
new_session; expect_block "US dashes" "call 555-123-4567 today" "phone number: 555-123-4567"
new_session; expect_block "phone at start of prompt" "555-123-4567 is my cell" "phone number: 555-123-4567"
new_session; expect_block "SSN at start of prompt" "123-45-6789" "Social Security number: …-6789"
new_session; expect_block "US parens" "call (555) 123-4567" "phone number: (555) 123-4567"
new_session; expect_block "US +1 dots" "call +1 555.123.4567" "phone number: +1 555.123.4567"
new_session; expect_block "international" "office: +44 20 7946 0958. Thanks" "phone number: +44 20 7946 0958"
new_session; expect_pass  "date is not a phone" "released 2026-11-15 at 10:30"
new_session; expect_pass  "version / IP not a phone" "v1.2.3 on 192.168.1.20"
new_session; expect_block "bare 10 digits" "my cell is 5551234567" "phone number: 5551234567"
new_session; expect_block "bare 10 digits at start" "5551234567" "phone number: 5551234567"
new_session; expect_block "10-digit unix timestamp is flagged too" "ts=1731700000 done" "phone number: 1731700000"
new_session; expect_pass  "8 digits" "ticket 12345678"
new_session; expect_pass  "11 digits" "order 12345678901"
new_session; expect_pass  "10 digits inside hex" "commit a1b2c3d45551234567ef"
new_session; expect_pass  "10 digits in a decimal" "pi is 3.1415926535"

echo "Social Security numbers"
new_session; expect_block "SSN dashes" "my ssn is 123-45-6789" "Social Security number: …-6789"
new_session; expect_block "bare 9 digits" "ssn 123456789" "Social Security number: …6789"
new_session; expect_pass  "invalid SSN area 000" "code 000-12-3456"
new_session; expect_pass  "mixed separators" "part 123-45 6789"

echo "Card numbers"
new_session; expect_block "Visa spaced" "card 4111 1111 1111 1111 exp 12/27" "card number: 4111 …1111"
new_session; expect_block "Visa solid" "4111111111111111" "card number: 4111 …1111"
new_session; expect_block "Mastercard dashes" "5555-5555-5555-4444" "card number: 5555 …4444"
new_session; expect_block "Amex 4-6-5" "amex 3782 822463 10005" "card number: 3782 …0005"
new_session; expect_pass  "16 digits failing checksum" "order 4111111111111112"
new_session; expect_pass  "ms timestamp" "at 1731700000000"
new_session; expect_pass  "card-like inside hex" "sha deadbeef4111111111111111cafe"
new_session; expect_block "two phones are not a card" "555-123-4567 555-987-6543" "phone number: 555-123-4567" "phone number: 555-987-6543"

echo "Mixed and pasted"
new_session; expect_block "log with several" $'ERROR user=j.ortiz@acme.com\ncard=4111111111111111 tel=555-123-4567' "email: j.ortiz@acme.com" "card number: 4111 …1111" "phone number: 555-123-4567"
new_session; expect_block "pasted marker lines" $'fix this\n<pasted_content id="9f2c5555123456">\nreach me at 555-123-4567\n</pasted_content id="9f2c5555123456">' "phone number: 555-123-4567"
new_session; expect_pass  "pasted marker ids alone" $'<pasted_content id="4111111111111111">\nhello\n</pasted_content id="4111111111111111">'
new_session; expect_block "unicode and escapes around" $'café — "quoted" \\ back\\slash\n\tmail me: a@b.io' "email: a@b.io"
new_session; expect_block "listed once when repeated" "a@b.io and a@b.io" "email: a@b.io"

echo "Clean prompts"
new_session; expect_pass "plain question" "now write a test for it"
new_session; expect_pass "code" 'for (let i = 0; i < 10; i++) { console.log("hi"); }'
new_session; expect_pass "empty prompt" ""
new_session; expect_pass "at sign in code" "use @Override and npm i @types/node"

echo "Send anyway"
new_session
P="email j.ortiz@acme.com"
expect_block "first send is held" "$P" "send the exact same prompt again within 1 minute"
expect_pass  "same prompt again goes through" "$P"
expect_block "a third send is checked again" "$P" "email"
new_session
expect_block "held" "$P" "email"
expect_block "changed prompt is checked again" "$P!" "email"
new_session
expect_block "held (for expiry test)" "$P" "email"
F="$(ls "$TMPDIR"/pii-check-*/held-"$SESSION")"
read -r T H < "$F"; printf '%s %s\n' "$((T - 61))" "$H" > "$F"
expect_block "same prompt after 61s is checked again" "$P" "email"
new_session
expect_block "held in one session" "$P" "email"
SESSION_A=$SESSION; new_session
expect_block "same prompt in another session is checked" "$P" "email"

echo "What's written to disk"
new_session
SECRET="unique-marker-$RANDOM j.ortiz@acme.com"
run "$SECRET" >/dev/null
if grep -rq -e "unique-marker" -e "acme" "$TMPDIR"; then bad "no prompt text on disk" "found prompt text in $TMPDIR"; else ok "no prompt text on disk"; fi
F="$(ls "$TMPDIR"/pii-check-*/held-"$SESSION")"
if grep -Eq '^[0-9]+ [0-9a-f]{64}$' "$F"; then ok "state file holds only a time and a fingerprint"; else bad "state file format" "$(cat "$F")"; fi

echo "Fails closed"
out="$(printf 'not json' | bash "$HOOK")"
case "$out" in *'"decision":"block"'*"ran into a problem"*) ok "bad input is held";; *) bad "bad input is held" "$out";; esac
out="$(run "a@b.io" | true; jq -n '{prompt:"hi a@b.io"}' | PII_CHECK_AWK=/nonexistent/awk bash "$HOOK")"
case "$out" in *'"decision":"block"'*"ran into a problem"*) ok "missing awk is held";; *) bad "missing awk is held" "$out";; esac

echo "Speed"
BIG="$(for i in $(seq 1 20000); do echo "2026-11-15T10:30:00Z INFO request id=$i took ${i}ms status=200 path=/api/v1/items/$i"; done)"
start=$(date +%s%N); out="$(run "$BIG")"; end=$(date +%s%N)
ms=$(( (end - start) / 1000000 ))
[ -z "$out" ] && [ "$ms" -lt 3000 ] && ok "20,000-line clean log in ${ms}ms" || bad "big clean log" "took ${ms}ms, output: ${out:0:200}"
start=$(date +%s%N); out="$(run "now write a test for it")"; end=$(date +%s%N)
ms=$(( (end - start) / 1000000 ))
[ "$ms" -lt 200 ] && ok "short prompt in ${ms}ms" || bad "short prompt speed" "took ${ms}ms"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
