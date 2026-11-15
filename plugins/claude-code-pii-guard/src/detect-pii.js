const CATEGORY = Object.freeze({
  personal: "Names or personal identifiers",
  contact: "Email or phone details",
  financial: "Financial identifiers",
  health: "Health or sensitive details",
  credentials: "Credentials or secrets",
});

const EMAIL = /\b[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+\b/giu;
const NAME_FIELD =
  /\b(?<label>full[\s_-]?name|first[\s_-]?name|last[\s_-]?name|name)\s*[:=]\s*(?:"(?<quoted>[^"\n]{1,80})"|'(?<single>[^'\n]{1,80})'|(?<plain>[^\n,;]{1,80}))/giu;
const PHONE_FIELD =
  /\b(?:phone|mobile|cell(?:phone)?|telephone|tel)\s*(?:number|no\.?)?\s*[:=]\s*(?<value>\+?[\d(][\d ().-]{5,23}\d)\b/giu;
const INTERNATIONAL_PHONE = /(?<![\w])\+\d(?:[\d ().-]{5,22}\d)\b/g;
const CARD_NUMBER = /(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)/g;
const BANK_IDENTIFIER =
  /\b(?:bank\s+account|account(?:\s+number)?|routing(?:\s+number)?|iban|sort\s+code)\s*[:=]\s*(?<value>[A-Z0-9][A-Z0-9 -]{5,33})/giu;
const SENSITIVE_IDENTIFIER =
  /\b(?<label>ssn|social security number|passport number|national id|date of birth|dob|home address|mailing address)\s*[:=]\s*(?:"(?<quoted>[^"\n]{2,120})"|'(?<single>[^'\n]{2,120})'|(?<plain>[^\n,;]{2,120}))/giu;
const HEALTH_FIELD =
  /\b(?:diagnosis|medical condition|prescription|patient id|medical record(?:\s+number)?|mrn)\s*(?:is\s+|[:=]\s*)(?:"(?<quoted>[^"\n]{2,120})"|'(?<single>[^'\n]{2,120})'|(?<plain>[^\n,;]{2,120}))/giu;
const FIRST_PERSON_HEALTH =
  /\b(?:I|my (?:partner|child|parent))\s+(?:was\s+)?(?:diagnosed with|prescribed)\s+(?<value>[^\n,;.]{2,120})/giu;
const LABELLED_CREDENTIAL =
  /\b(?:password|passwd|secret|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|private[_ -]?key)\s*[:=]\s*(?:"(?<quoted>[^"\n]{4,180})"|'(?<single>[^'\n]{4,180})'|(?<plain>[^\s,;]{4,180}))/giu;
const KNOWN_TOKEN =
  /\b(?:sk_(?:live|test)|gh[pousr]|github_pat|glpat|xox[baprs])_[A-Za-z0-9_-]{12,}\b|\bAKIA[0-9A-Z]{16}\b|\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/g;

const PLACEHOLDERS = new Set([
  "example",
  "example value",
  "placeholder",
  "redacted",
  "removed",
  "changeme",
  "change_me",
  "your value",
  "your name",
  "your email",
  "your token",
  "your api key",
]);

function valueFrom(match) {
  return (
    match.groups?.quoted ??
    match.groups?.single ??
    match.groups?.plain ??
    match.groups?.value ??
    ""
  ).trim();
}

function isPlaceholder(value) {
  const normalized = value
    .trim()
    .replace(/^["'`<[\s]+|["'`>\]\s]+$/g, "")
    .toLowerCase();

  return (
    PLACEHOLDERS.has(normalized) ||
    /^your[-_ ]/.test(normalized) ||
    /^\[?(?:redacted|removed|placeholder)\]?$/i.test(normalized)
  );
}

function looksLikePersonName(label, value) {
  if (!value || isPlaceholder(value)) return false;

  const normalizedLabel = label.toLowerCase().replace(/[\s_-]/g, "");
  const parts = value.trim().split(/\s+/);
  const isNamePart = (part) => /^\p{Lu}[\p{L}\p{M}'’-]+$/u.test(part);

  if (normalizedLabel === "firstname" || normalizedLabel === "lastname") {
    return parts.length === 1 && isNamePart(parts[0]);
  }

  return parts.length >= 2 && parts.length <= 4 && parts.every(isNamePart);
}

function digitCount(value) {
  return (value.match(/\d/g) ?? []).length;
}

function passesLuhn(value) {
  const digits = value.replace(/\D/g, "");
  if (digits.length < 13 || digits.length > 19 || /^(\d)\1+$/.test(digits)) {
    return false;
  }

  let sum = 0;
  let double = false;
  for (let index = digits.length - 1; index >= 0; index -= 1) {
    let digit = Number(digits[index]);
    if (double) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    double = !double;
  }

  return sum % 10 === 0;
}

function addMatch(matches, category, start, end) {
  if (matches.some((item) => item.category === category && start < item.end && end > item.start)) {
    return;
  }

  matches.push({ category, start, end });
}

function collectMatches(text, pattern, category, matches, validate = () => true) {
  pattern.lastIndex = 0;
  let match;

  while ((match = pattern.exec(text)) !== null) {
    if (validate(match)) {
      addMatch(matches, category, match.index, match.index + match[0].length);
    }
    if (match[0].length === 0) pattern.lastIndex += 1;
  }

  pattern.lastIndex = 0;
}

/**
 * Detects likely PII using local, high-confidence patterns.
 * The return value intentionally contains categories and counts only, never matched text.
 *
 * @param {string} text
 * @returns {{ category: string, count: number }[]}
 */
export function detectPii(text) {
  if (typeof text !== "string" || text.length === 0) return [];

  const matches = [];

  collectMatches(text, EMAIL, CATEGORY.contact, matches);
  collectMatches(text, NAME_FIELD, CATEGORY.personal, matches, (match) =>
    looksLikePersonName(match.groups?.label ?? "", valueFrom(match)),
  );
  collectMatches(text, PHONE_FIELD, CATEGORY.contact, matches, (match) => {
    const digits = digitCount(valueFrom(match));
    return digits >= 8 && digits <= 15;
  });
  collectMatches(text, INTERNATIONAL_PHONE, CATEGORY.contact, matches, (match) => {
    const digits = digitCount(match[0]);
    return digits >= 8 && digits <= 15;
  });
  collectMatches(text, CARD_NUMBER, CATEGORY.financial, matches, (match) =>
    passesLuhn(match[0]),
  );
  collectMatches(text, BANK_IDENTIFIER, CATEGORY.financial, matches, (match) =>
    !isPlaceholder(valueFrom(match)),
  );
  collectMatches(text, SENSITIVE_IDENTIFIER, CATEGORY.personal, matches, (match) => {
    const value = valueFrom(match);
    return value.length >= 2 && !isPlaceholder(value);
  });
  collectMatches(text, HEALTH_FIELD, CATEGORY.health, matches, (match) =>
    !isPlaceholder(valueFrom(match)),
  );
  collectMatches(text, FIRST_PERSON_HEALTH, CATEGORY.health, matches, (match) =>
    !isPlaceholder(valueFrom(match)),
  );
  collectMatches(text, LABELLED_CREDENTIAL, CATEGORY.credentials, matches, (match) =>
    !isPlaceholder(valueFrom(match)),
  );
  collectMatches(text, KNOWN_TOKEN, CATEGORY.credentials, matches);

  const counts = new Map();
  for (const { category } of matches) {
    counts.set(category, (counts.get(category) ?? 0) + 1);
  }

  return [...counts].map(([category, count]) => ({ category, count }));
}
