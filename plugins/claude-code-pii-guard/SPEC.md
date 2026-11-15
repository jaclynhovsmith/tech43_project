# Claude Code PII Guard — MVP Spec

**Status:** Draft  
**Audience:** Solo developer  
**Target:** Claude Code

## Problem

A developer can accidentally submit personal information or credentials in a prompt. They need a last local check before Claude Code processes typed text.

## Proposed solution

A Claude Code mod checks the submitted prompt on the user's machine. If high-confidence patterns match, it asks whether to send the prompt unchanged, return it for editing, or cancel. No prompt text leaves the local hook, and no raw prompt is logged or stored by the mod.

## MVP scope

- Inspect typed prompts at `prompt.submit` only.
- Detect high-confidence examples in these categories:
  - Names and personal identifiers, when explicitly labelled.
  - Email addresses and labelled or international phone numbers.
  - Financial identifiers, including Luhn-valid payment card numbers and labelled account details.
  - Health or sensitive details, when explicitly labelled or phrased as a first-person diagnosis or prescription.
  - Credentials and secrets, when labelled or matching common token formats.
- Show only category names and counts in the confirmation; never show matched values or prompt excerpts.
- Offer **Send as written**, **Edit prompt**, and **Cancel**.
- Proceed only when the user selects **Send as written**. Editing, canceling, dismissing, an unrecognized answer, or a confirmation error must not submit the prompt.
- Use local rules only. Do not call a model, network service, or integration.
- Do not persist prompt text, detected values, or detection history.

## Non-goals

- Inspect tool inputs, files, conversation history, or system context.
- Guarantee complete PII detection or replace an organization's data-loss-prevention policy.
- Send prompts to an external service for analysis.
- Provide organization-wide controls, dashboards, or audit logs.

## Acceptance criteria

- Given a prompt with no supported high-confidence match, when it is submitted, then it proceeds without a confirmation dialog.
- Given a supported match, when the user chooses **Send as written**, then the original prompt proceeds unchanged.
- Given a supported match, when the user chooses **Edit prompt**, then the prompt is not submitted and is returned to the input.
- Given a supported match, when the user cancels, dismisses, or enters another answer, then the prompt is not submitted.
- Given a supported match, when the confirmation UI fails, then the prompt is not submitted.
- Given any prompt, when the warning is shown or a finding is returned, then matched values are not included.
- Given any prompt, when detection completes, then no prompt contents or findings are written to logs or persistent storage.

## Limitations

This MVP favors fewer false alarms over broad coverage. Local patterns cannot reliably identify every name, health detail, or secret format. A clean result must not be presented as proof that a prompt contains no PII.

## Technical reference

- [Claude Code mod events](https://code.claude.com/docs/en/plugins/mods/events)
- [Claude Code mod interface](https://code.claude.com/docs/en/plugins/mods/interface)
