import assert from "node:assert/strict";
import test from "node:test";
import { register } from "../hooks/register.js";

function getPromptSubmitHook() {
  let hook;
  register((eventName, handler) => {
    assert.equal(eventName, "prompt.submit");
    hook = handler;
  });
  return hook;
}

test("passes prompts without findings through unchanged", async () => {
  const hook = getPromptSubmitHook();
  const prompt = { text: "Summarize the README." };
  let asked = false;
  let forwarded;

  const result = await hook(
    { ui: { ask: async () => (asked = true) } },
    prompt,
    async (event) => {
      forwarded = event;
      return { ok: true };
    },
  );

  assert.equal(asked, false);
  assert.equal(forwarded, prompt);
  assert.deepEqual(result, { ok: true });
});

test("shows categories but never the matched prompt text", async () => {
  const hook = getPromptSubmitHook();
  const prompt = { text: "Email alex.person@example.test" };
  let question = "";
  let forwarded;

  await hook(
    {
      ui: {
        ask: async (message, choices) => {
          question = message;
          assert.deepEqual(choices, ["Send as written", "Edit prompt", "Cancel"]);
          return "Send as written";
        },
      },
    },
    prompt,
    async (event) => {
      forwarded = event;
      return { ok: true };
    },
  );

  assert.match(question, /Email or phone details/);
  assert.equal(question.includes("alex.person@example.test"), false);
  assert.equal(forwarded, prompt);
});

test("returns prompts for editing without submitting them", async () => {
  const hook = getPromptSubmitHook();
  let forwarded = false;

  const result = await hook(
    { ui: { ask: async () => "Edit prompt" } },
    { text: "Email alex.person@example.test" },
    async () => {
      forwarded = true;
    },
  );

  assert.equal(forwarded, false);
  assert.match(result.drop, /returned to the input/);
});

test("cancels a flagged prompt without submitting it", async () => {
  const hook = getPromptSubmitHook();
  let forwarded = false;

  const result = await hook(
    { ui: { ask: async () => "Cancel" } },
    { text: "Email alex.person@example.test" },
    async () => {
      forwarded = true;
    },
  );

  assert.equal(forwarded, false);
  assert.match(result.drop, /canceled/);
});

test("does not treat a custom or dismissed answer as confirmation", async () => {
  const hook = getPromptSubmitHook();
  let forwarded = false;

  const result = await hook(
    { ui: { ask: async () => "Maybe later" } },
    { text: "Email alex.person@example.test" },
    async () => {
      forwarded = true;
    },
  );

  assert.equal(forwarded, false);
  assert.match(result.drop, /canceled/);
});

test("fails closed if confirmation cannot be shown", async () => {
  const hook = getPromptSubmitHook();
  let forwarded = false;

  const result = await hook(
    {
      ui: {
        ask: async () => {
          throw new Error("dialog unavailable");
        },
      },
    },
    { text: "Email alex.person@example.test" },
    async () => {
      forwarded = true;
    },
  );

  assert.equal(forwarded, false);
  assert.match(result.drop, /could not get confirmation/);
});

test("fails closed if the hook receives an invalid event", async () => {
  const hook = getPromptSubmitHook();
  let forwarded = false;

  const result = await hook({}, null, async () => {
    forwarded = true;
  });

  assert.equal(forwarded, false);
  assert.match(result.drop, /privacy check failed/);
});
