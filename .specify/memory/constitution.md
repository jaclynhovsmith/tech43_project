# PII Guard Constitution

## Core Principles

### I. Local Only
The check runs entirely on the user's computer. It never sends prompt text, or anything derived from it, to a model, network service or integration.

### II. Never Persist
The plugin never writes prompt text, detected values or detection history to logs, files or any other storage.

### III. The User Stays in Control
The plugin warns and asks; it never changes what the user wrote. A held prompt goes through only when the user explicitly chooses to send it. Editing, cancelling, dismissing, an unrecognised answer or a failure in the check must not send it (fail closed).

### IV. Clean Prompts Pass Silently
A prompt with nothing to flag goes through with no prompt, dialog or noticeable delay.

### V. A Safety Net, Not a Guarantee
The plugin never presents a clean result as proof that a prompt has no personal info or secrets. Scope is typed or pasted prompts only, not files, tool input, command output or Claude's replies.

## Additional Constraints

- Works out of the box: no account, no sign-up, no paid service, no runtime dependencies to install.
- Installs through Claude Code's normal plugin mechanism.

## Development Workflow

- Each feature has a spec with acceptance criteria before it is built.
- Every behaviour in a spec has an automated test, and the full test suite passes before a change is merged.

## Governance

This constitution overrides other practices in this repository. Amendments are made by editing this file, with the reason recorded in the commit message. Specs that conflict with it are changed to match, or the constitution is amended first.

Not yet decided, so deliberately left out: whether a warning shows the matched text (`specdriven/concept.md`) or only categories and counts (`plugins/claude-code-pii-guard/SPEC.md`).

**Version**: 1.0.0 | **Ratified**: 2026-11-15 | **Last Amended**: 2026-11-15
