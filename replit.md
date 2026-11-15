# Claude Code PII Guard

A local Claude Code mod that checks typed prompts for likely personal information before submission.

## Run & Operate

- `pnpm --filter @workspace/claude-code-pii-guard test` — run plugin tests
- `pnpm --filter @workspace/claude-code-pii-guard check` — check JavaScript syntax
- `claude --plugin-dir ./plugins/claude-code-pii-guard` — load the plugin in Claude Code

## Stack

- pnpm workspaces and Node.js
- Claude Code mod hooks
- Node.js built-in test runner; no runtime dependencies

## Where things live

- `plugins/claude-code-pii-guard/SPEC.md` — MVP behavior and acceptance criteria
- `plugins/claude-code-pii-guard/src/detect-pii.js` — local high-confidence detection rules
- `plugins/claude-code-pii-guard/hooks/register.js` — pre-submit confirmation flow
- `plugins/claude-code-pii-guard/test/` — detector and hook tests

## Architecture decisions

- Inspect typed prompts only; do not inspect tool inputs or files in the MVP.
- Detect on-device with explicit patterns; do not call a remote model or service.
- Never log or persist prompt text. Confirmation displays categories and counts, not matched values.
- If a finding is present, only the explicit “Send as written” choice proceeds; dismissal and hook errors stop submission.

## Product

- Warns before a typed Claude Code prompt containing likely personal identifiers, contact information, financial identifiers, health or sensitive details, or credentials is submitted.
- Offers to send unchanged, return the prompt for editing, or cancel.

## User preferences

- Prioritize high-confidence matches to reduce false alarms.

## Gotchas

- Name and health detection is intentionally limited to explicit, high-confidence text patterns; this is a warning aid, not a guarantee that all PII will be detected.

## Pointers

- Claude Code mod docs: https://code.claude.com/docs/en/plugins/mods/events
