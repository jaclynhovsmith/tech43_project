# Claude Code PII Guard

A local Claude Code mod that checks typed prompts for likely personal information before submission.

## What it does

- Checks only the prompt text typed by the user.
- Uses local, high-confidence patterns for names and identifiers, contact details, financial identifiers, health or sensitive details, and credentials.
- Shows categories and counts only; it never displays matched values or prompt excerpts.
- Offers to send unchanged, return the prompt for editing, or cancel.
- Does not make network calls, log prompt contents, or persist detections.

Detection is intentionally incomplete. A prompt with no warning is not guaranteed to be free of PII.

## Load locally

From the repository root, start Claude Code with:

```sh
claude --plugin-dir ./plugins/claude-code-pii-guard
```

The plugin requires a Claude Code build with Mods support. If no match is found, the prompt continues normally. If a match is found, only **Send as written** continues; all other outcomes return the prompt to the input without submitting it.

## Development

```sh
pnpm --filter @workspace/claude-code-pii-guard check
pnpm --filter @workspace/claude-code-pii-guard test
```
