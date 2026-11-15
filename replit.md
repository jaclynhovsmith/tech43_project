# PII Check

A Claude Code plugin that holds back a prompt containing personal info or a secret until you confirm by sending it again. Runs entirely on your computer.

## Run & Operate

- `bash tests/run-tests.sh` — run the check's tests
- `claude --plugin-dir .` — load the plugin in Claude Code

## Where things live

- `specdriven/` — concept, roadmap and feature cards (the specs)
- `.specify/memory/constitution.md` — project principles
- `.claude-plugin/plugin.json` — plugin manifest
- `hooks/hooks.json` — registers the `UserPromptSubmit` hook
- `scripts/check-prompt.sh` — the hook; reads the prompt and decides
- `scripts/detect.awk` — the detection rules
- `tests/run-tests.sh` — tests

## Architecture decisions

- Inspect typed or pasted prompts only; not files, tool input or replies.
- Detect on-device with explicit patterns; never call a remote model or service.
- Never log or save prompt text or findings.
- The warning lists each item found, labelled by kind, with the text that triggered it.
- To send a held prompt anyway, send the exact same prompt again within 1 minute. If the check fails, the prompt is held.

## Gotchas

- This is a safety net, not a guarantee that all personal info is caught.
