import assert from "node:assert/strict";
import test from "node:test";
import { detectPii } from "../src/detect-pii.js";

test("detects an email without returning the address", () => {
  const findings = detectPii("Contact Alex at alex.person@example.test");

  assert.deepEqual(findings, [{ category: "Email or phone details", count: 1 }]);
  assert.equal(JSON.stringify(findings).includes("alex.person@example.test"), false);
});

test("detects an explicitly labelled person name", () => {
  assert.deepEqual(detectPii("full_name: Jordan Example"), [
    { category: "Names or personal identifiers", count: 1 },
  ]);
});

test("ignores project names that are not person names", () => {
  assert.deepEqual(detectPii("name: my-demo-project"), []);
});

test("detects labelled and international phone numbers", () => {
  assert.deepEqual(detectPii("phone: (415) 555-0138"), [
    { category: "Email or phone details", count: 1 },
  ]);
  assert.deepEqual(detectPii("Call +1 415 555 0138"), [
    { category: "Email or phone details", count: 1 },
  ]);
});

test("detects a payment card only when it passes Luhn validation", () => {
  assert.deepEqual(detectPii("card 4111 1111 1111 1111"), [
    { category: "Financial identifiers", count: 1 },
  ]);
  assert.deepEqual(detectPii("card 4111 1111 1111 1112"), []);
});

test("detects labelled health and personal identifier fields", () => {
  assert.deepEqual(detectPii("diagnosis: Type 1 diabetes"), [
    { category: "Health or sensitive details", count: 1 },
  ]);
  assert.deepEqual(detectPii("date of birth: 1984-03-12"), [
    { category: "Names or personal identifiers", count: 1 },
  ]);
});

test("ignores redacted health and financial fields", () => {
  assert.deepEqual(detectPii("diagnosis: [redacted]"), []);
  assert.deepEqual(detectPii("account number: redacted"), []);
});

test("detects labelled credentials but skips obvious placeholders", () => {
  assert.deepEqual(detectPii("password: sample-secret-value"), [
    { category: "Credentials or secrets", count: 1 },
  ]);
  assert.deepEqual(detectPii("password: [redacted]"), []);
});

test("returns an empty result for non-text input", () => {
  assert.deepEqual(detectPii(null), []);
});
