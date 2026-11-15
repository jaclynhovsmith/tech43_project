# Feature 2 — Catch secrets

**Status.** approved

From: roadmap.md item #2

**What it does.** Adds passwords, API keys, access tokens and private keys to the same warning as feature #1. A prompt containing one is held back. You send it again within a minute to send it anyway, or edit it. In the warning, a secret is never shown in full.

**User flow.** Same as feature #1. The warning now says "personal info or secrets" and lists items like `GitHub token: ghp_…` or `password: DB_PASSWORD=…`.

**Acceptance checks.**
- [x] Private keys are caught from their `-----BEGIN … PRIVATE KEY-----` line. Public keys and certificates are not.
- [x] Well-known key and token formats are caught: AWS, GitHub, GitLab, Slack, Stripe, OpenAI, Anthropic, Google, npm, SendGrid, and JSON Web Tokens.
- [x] A password, secret, token or API key written as a setting is caught: `password=…`, `"api_key": "…"`, `--token …`, `Authorization: Bearer …` (or `Basic`/`Token`), and `https://user:pass@host` web addresses.
- [x] Common code doesn't trigger it: `password = os.environ["DB_PASSWORD"]`, `token: string`, `password == input`, `apiKey = config.apiKey`, `max_tokens=1000`, `api_key="YOUR_API_KEY"`.
- [x] The warning never shows a whole secret, only its kind and the start of it, or the setting's name. When a secret is found, Claude Code's "Original prompt: …" line is hidden too (your choice b). It's still shown for personal info only.
- [x] Digits inside a secret don't also show up as a phone or card number.
- [x] Everything from feature #1 still passes, with no noticeable slowdown.

**Tech notes.**
- Same hook. New checks in `detect.awk` run before the personal-info checks and mark their text as used.
- Feature #1 skips lines with no digit or `@` for speed. That would skip `password=hunter`, so the skip has to allow `:`, `=` and `-` too.
- Known formats: a fixed start (`ghp_`, `AKIA`, `sk-ant-`…) plus a minimum length, checked with `length()` (no `{n}`).
- Settings: find a key name ending in password/passwd/pwd/passphrase/secret/token, or in api/access/private/secret/auth/signing/encryption + key (`SECRET_KEY`, `AWS_SECRET_ACCESS_KEY`). Then `:` or `=`, or a space after a `--flag`. Then read the value, quoted or not, stopping at whitespace, `&`, `,` or `;`, and reject variable references, code, type names, placeholders, booleans and short values.
- Matching ignores letter case by checking a lowercase copy of each line.
- Hidden prompt: the hook adds `suppressOriginalPrompt: true` when any finding is a secret.
- Each search only runs when its fixed text (`ghp_`, `://`, `bearer`, `pass`…) is in the line, which keeps a 20,000-line paste around 0.5s.
- Also checked against about 156,000 lines of real code. Square brackets and code keywords (`function`) as values are not counted as secrets.

**Assumptions.**
- Assumed: a random-looking string with no label and no known start (`a8f3k2…`) is not flagged, because hashes and IDs look identical.
- Assumed: obvious placeholders aren't flagged: values containing "your", "example", "placeholder", "redacted", `xxx` or `***`, and values made of one repeated character.
- Confirmed in the interactive app: after a block, Claude Code puts the stopped prompt back in the input box, so pressing Enter sends it anyway, even when it's hidden from the warning.
- Assumed: test keys (`sk_test_…`) are flagged like live ones.
- Assumed: fake credentials in test files that look real (`secret: 'supersekrit'`) are flagged, because the plugin can't tell them from real ones.
