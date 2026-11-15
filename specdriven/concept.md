# Concept: A "are you sure?" check for personal info in Claude Code prompts

**Status.** approved

**Elevator pitch.** A free Claude Code plugin that notices when you're about to send personal information or a secret, like a phone number, someone's name or an API key, and asks "Are you sure you want to send this?" before it goes anywhere.

**Who's it for.** Anyone who uses Claude Code and wants a safety net, especially people who paste in logs, customer records, emails or config files without reading every line. It's published publicly so anyone can install it.

**The problem.** Once you send a prompt, it's gone. It's easy to paste a block of text with a customer's email, a coworker's name or a live password buried in it, and today nothing stops you or even tells you.

**Done looks like.**
- When a prompt contains personal info or a secret, it's held back before sending, and you see what was found and where.
- You choose: send it anyway, or go back and edit it.
- Prompts with nothing sensitive go through with no delay or extra step.
- When it's unsure, it warns anyway, and you can quickly silence things you know are fine so the warnings stay worth reading.
- A stranger can find it, install it and have it working in a couple of minutes using Claude Code's normal plugin install.

**Ground rules.**
- The check itself never sends your text anywhere. It runs only on your own computer.
- You always stay in control. It warns and asks, and never changes what you wrote.
- The plugin never saves what it finds. (Claude Code itself keeps your prompt history on your computer, including stopped prompts.)
- It works out of the box, with no account, no sign-up and no paid service.

**Out of scope.**
- Scanning files, command output or Claude's replies. Only what you type or paste as a prompt.
- Automatically blanking out what it found.
- Team or company settings, dashboards or reports.
- Guaranteeing that everything sensitive is caught. It's a safety net, not a compliance tool.

**What it catches.**
- Personal info with a fixed format: email addresses, phone numbers, government ID numbers (like US Social Security numbers) and credit card numbers.
- Fuzzier personal info: people's names and street addresses.
- Secrets: passwords, API keys, access tokens and private keys.

**Assumptions.**
- Assumed: when it warns you, it lists each item it found, labeled by kind ("email", "API key") with the part that triggered it, so you can see exactly why.
- Assumed: you can tell it to stop flagging a specific thing, like your own name or work email, and that list is kept on your computer.
- Assumed: you can turn a whole kind of check on or off, for example turning off names if they cause too many false alarms.
- Assumed: it starts with US and common international formats. Other countries' ID numbers can come later.
- Assumed: the warning is plain text in Claude Code, with no extra windows or pop-ups.

**Open questions.**
- ? Exactly how "send it anyway" feels in Claude Code, for example one keypress or resending the prompt. This depends on what Claude Code lets a plugin do and gets settled in the first feature card.
