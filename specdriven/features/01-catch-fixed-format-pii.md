# Feature 1 — Catch fixed-format personal info and hold the prompt

**Status.** approved

From: roadmap.md item #1

**What it does.** Before Claude Code sends a prompt, the plugin checks it for email addresses, phone numbers, US Social Security numbers and credit card numbers. If it finds any, the prompt is held back and you see what was found. To send it anyway, you send the exact same prompt again within a minute. Or you edit it and send that instead. Clean prompts go through untouched.

**User flow.**
1. You type or paste a prompt and press Enter.
2. Nothing found: the prompt goes to Claude as normal, with no message.
3. Something found: the prompt doesn't reach Claude. You see a short warning listing each item, for example `email: j.ortiz@acme.com` or `card number: 4111 …1111`, ending with "To send it anyway, send the same prompt again within 1 minute."
4. You either send the same prompt again within a minute, and it goes through, or edit it and send, and it's checked again.

**Acceptance checks.**
- [x] A prompt containing an email address is held back, and the warning names it as an email and shows it.
- [x] Phone numbers, US Social Security numbers and credit card numbers are each caught the same way, both on their own and mixed in a longer prompt.
- [x] A prompt with nothing sensitive goes through with no message and no noticeable delay.
- [x] Pasted text, including long pastes that Claude Code collapses to `[Pasted text]`, is checked the same as typed text. *(Checked with test input, and with a real 40-line paste in the interactive app.)*
- [x] Sending the exact same held prompt again within 1 minute lets it through. After more than a minute, or with any change, it's checked again. The prompt after that is checked as normal.
- [x] If the check crashes or takes too long, the prompt is held back. Errors inside the check show a message saying it failed and how to turn the plugin off. If it can't start at all or times out, Claude Code's own message appears instead (accepted; the turn-off steps go in the README in roadmap #5).
- [x] The plugin never saves what it found and sends nothing over the network.

**Tech notes.**
- A Claude Code plugin with one `UserPromptSubmit` command hook. It reads the prompt from stdin and returns `decision: "block"` with a `reason` listing the findings.
- Send anyway: when the hook blocks a prompt, it saves a one-way fingerprint (SHA-256) of the prompt text and the time in a small file in a temporary folder. If the next prompt has the same fingerprint within 60 seconds, it's allowed through and the file is deleted. The file never contains the text or the findings.
- Fail closed: set `onFailure: "block"` and a short `timeout` on the hook. Any error inside the script also blocks.
- Card numbers are confirmed with the standard card checksum (Luhn).
- Written in bash + POSIX awk (`scripts/check-prompt.sh`, `scripts/detect.awk`), which every Claude Code install has, including Windows through Git Bash. Avoids awk features that differ between versions. Tested on mawk only so far.
- Tests: `tests/run-tests.sh` (54 checks; needs jq).

**Assumptions.**
- Assumed: card numbers (`4111 …1111`) and Social Security numbers (`…-6789`) are partly hidden in the warning. Emails and phone numbers are shown in full so you can recognize them.
- Assumed: phone numbers cover US formats and international `+` formats. Other countries' ID numbers wait for later.
- Assumed: the check also runs on prompts Claude Code sends on its own (scheduled tasks, background agents reporting back), because the plugin can't reliably tell those apart from what you typed.
- Assumed: to make "send the same prompt again" work, the plugin keeps a scrambled, one-way fingerprint of the held prompt for up to a minute. Your words can't be recovered from it.
- Confirmed: Claude Code shows the stopped prompt after the warning ("Original prompt: …"), so you can copy it to resend or edit. Also confirmed in the interactive app: after a block, the stopped prompt is put back in the input box, so pressing Enter resends it.
- Confirmed: phone numbers and Social Security numbers don't need separators. A bare run of exactly 10 digits (`5551234567`) is flagged as a phone number and exactly 9 digits (`123456789`) as a Social Security number. This also flags 10-digit timestamps and IDs.
- Assumed: a 9- or 10-digit run isn't flagged when it's glued to letters (`a1b2c35551234567ef`) or part of a decimal number (`3.1415926535`).
- Assumed: card numbers are written as one block or in groups of 4 (Amex style 4-6-5 too), start with 2–6, and pass the checksum.
- Tried in a Claude Code cloud session used from the Claude app: a message with a phone number was stopped, and the same message sent again right after went through. Still to confirm: whether the person resent it or the app resends stopped messages on its own (that would undo the protection).
- Assumed: the plugin is called `pii-check`.
