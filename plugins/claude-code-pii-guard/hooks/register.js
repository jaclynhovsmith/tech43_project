import { detectPii } from "../src/detect-pii.js";

const SEND_AS_WRITTEN = "Send as written";
const EDIT_PROMPT = "Edit prompt";
const CANCEL = "Cancel";
const FAILURE_MESSAGE =
  "The privacy check failed. This prompt was not sent and remains in the input.";

function describeFindings(findings) {
  return findings
    .map(({ category, count }) => `${category} (${count})`)
    .join("; ");
}

export function register(on) {
  on("prompt.submit", async ($, event, next) => {
    try {
      const findings = detectPii(event.text);
      if (findings.length === 0) {
        return next(event).catch(() => ({ drop: FAILURE_MESSAGE }));
      }

      const summary = describeFindings(findings);
      const choice = await $.ui
        .ask(
          `Possible personal information found: ${summary}. Send this prompt unchanged?`,
          [SEND_AS_WRITTEN, EDIT_PROMPT, CANCEL],
        )
        .catch(() => null);

      if (choice === null) {
        return {
          drop: "The privacy check could not get confirmation. This prompt was not sent and remains in the input.",
        };
      }

      if (choice === SEND_AS_WRITTEN) {
        return next(event).catch(() => ({ drop: FAILURE_MESSAGE }));
      }

      if (choice === EDIT_PROMPT) {
        return {
          drop: "This prompt was not sent and has been returned to the input for editing.",
        };
      }

      return {
        drop: "This prompt was canceled and was not sent. It remains in the input.",
      };
    } catch {
      return { drop: FAILURE_MESSAGE };
    }
  });
}
