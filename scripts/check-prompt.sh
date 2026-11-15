#!/usr/bin/env bash
# pii-check: UserPromptSubmit hook.
# Holds back a prompt that contains personal info. Sending the exact same prompt again
# within RESEND_WINDOW seconds lets it through. Fails closed: any error holds the prompt.
#
# The prompt text is kept only in memory. The only thing written to disk is a one-way
# SHA-256 fingerprint of a held prompt, deleted when it's used or replaced.

set -u
RESEND_WINDOW=60
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWK="${PII_CHECK_AWK:-awk}"

json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\t'/ }
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

block() {
    printf '{"decision":"block","reason":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}\n' "$(json_escape "$1")"
    exit 0
}

fail() {
    block "The personal-info check ran into a problem ($1), so your prompt was held back to be safe. It was NOT sent.
To turn the check off, run /plugin in Claude Code and disable pii-check, or run: claude plugin disable pii-check"
}

trap 'fail "unexpected error on line $LINENO"' ERR

fingerprint() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r | cut -d' ' -f1
    else return 1
    fi
}

INPUT="$(cat)" || fail "could not read the prompt"

FINDINGS="$(printf '%s' "$INPUT" | "$AWK" -v MODE=detect -f "$HERE/detect.awk")" || fail "the detector failed"
[ "$FINDINGS" = "NOPROMPT" ] && fail "no prompt text in the hook input"
[ -z "$FINDINGS" ] && exit 0

# Something was found. Was this exact prompt held back less than a minute ago?
SESSION="$(printf '%s' "$INPUT" | "$AWK" -v MODE=session -f "$HERE/detect.awk")" || SESSION=""
[ "$SESSION" = "NOPROMPT" ] && SESSION=""
SESSION="$(printf '%s' "$SESSION" | tr -cd 'A-Za-z0-9_-')"
STATE_DIR="${TMPDIR:-/tmp}"
STATE_DIR="${STATE_DIR%/}/pii-check-$(id -u 2>/dev/null || echo user)"
STATE_FILE="$STATE_DIR/held-${SESSION:-nosession}"

PRINT="$(printf '%s' "$INPUT" | "$AWK" -v MODE=raw -f "$HERE/detect.awk" | fingerprint)" || PRINT=""
NOW="$(date +%s)"

if [ -n "$PRINT" ] && [ -f "$STATE_FILE" ]; then
    read -r HELD_AT HELD_PRINT < "$STATE_FILE" || true
    if [ "${HELD_PRINT:-}" = "$PRINT" ] && [ $((NOW - ${HELD_AT:-0})) -le "$RESEND_WINDOW" ]; then
        rm -f "$STATE_FILE"
        exit 0
    fi
fi

LIST=""
while IFS=$'\t' read -r KIND SHOWN; do
    LIST="$LIST
  • $KIND: $SHOWN"
done <<< "$FINDINGS"

if [ -n "$PRINT" ] && mkdir -p -m 700 "$STATE_DIR" 2>/dev/null; then
    (umask 077 && printf '%s %s\n' "$NOW" "$PRINT" > "$STATE_FILE")
    NEXT="To send it anyway, send the exact same prompt again within 1 minute.
Or edit it and send again."
else
    NEXT="Edit it and send again. (Sending it anyway isn't available: no SHA-256 tool was found on this computer.)"
fi

block "Your prompt was NOT sent. It looks like it contains personal info or secrets:$LIST

$NEXT"
