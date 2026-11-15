# pii-check: reads the UserPromptSubmit hook JSON on stdin.
#
#   MODE=detect   prints one "kind<TAB>shown value" line per finding
#   MODE=raw      prints the prompt value exactly as it appears in the JSON (for fingerprinting)
#   MODE=session  prints the session_id
#
# Prints "NOPROMPT" (and nothing else) if the input has no top-level "prompt" string.
# Written for POSIX awk: no gawk extensions and no {n} regex intervals, so it runs on
# mawk, macOS awk and busybox awk.

{ J = J $0 "\n" }

END {
    # Hide escaped backslashes and quotes so every remaining " is a real string delimiter.
    gsub(/\\\\/, "\001", J)
    gsub(/\\"/, "\002", J)

    if (!top_level_value(MODE == "session" ? "session_id" : "prompt")) {
        print "NOPROMPT"
        exit 0
    }
    if (MODE == "raw" || MODE == "session") { printf "%s", VALUE; exit 0 }

    text = decode(VALUE)
    # Claude Code may wrap pasted text in marker lines; their random ids are not user data.
    gsub(/<\/?pasted_content id="[^"]*">/, " ", text)

    nlines = split(text, L, "\n")
    for (li = 1; li <= nlines; li++) check_line(L[li])

    for (k = 1; k <= NF_COUNT; k++) print FOUND[k]
}

# ---------- JSON ----------

# Finds the string value of a key in the top-level object. Sets VALUE (still escaped).
function top_level_value(key,    n, P, i, depth, between) {
    n = split(J, P, "\"")
    # Odd elements are structure between strings; even elements are string contents.
    depth = 0
    for (i = 1; i <= n; i += 2) {
        depth += count_chars(P[i], "{[") - count_chars(P[i], "}]")
        if (i + 3 <= n && depth == 1 && P[i + 1] == key) {
            between = P[i + 2]
            gsub(/[ \t\r\n]/, "", between)
            if (between == ":") { VALUE = P[i + 3]; return 1 }
        }
    }
    return 0
}

function count_chars(s, set,    c, i) {
    c = 0
    for (i = 1; i <= length(s); i++) if (index(set, substr(s, i, 1))) c++
    return c
}

function decode(s,    out, code) {
    gsub(/\\n/, "\n", s)
    gsub(/\\r/, "\n", s)
    gsub(/\\t/, " ", s)
    gsub(/\\[bf]/, " ", s)
    gsub(/\\\//, "/", s)
    out = ""
    while (match(s, /\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) {
        code = hexval(substr(s, RSTART + 2, 4))
        out = out substr(s, 1, RSTART - 1) (code >= 32 && code < 127 ? sprintf("%c", code) : (code == 10 ? "\n" : " "))
        s = substr(s, RSTART + RLENGTH)
    }
    s = out s
    gsub(/\002/, "\"", s)
    gsub(/\001/, "\\", s)
    return s
}

function hexval(h,    v, i) {
    v = 0
    h = tolower(h)
    for (i = 1; i <= 4; i++) v = v * 16 + index("0123456789abcdef", substr(h, i, 1)) - 1
    return v
}

# ---------- detection ----------

function check_line(line,    p) {
    if (line !~ /[0-9@:=-]/) return
    for (p in COVER) delete COVER[p]
    check_secrets(line)
    scan(line, "email")
    scan(line, "card")
    scan(line, "ssn")
    scan(line, "us_phone")
    scan(line, "intl_phone")
    scan(line, "bare")
}

function pattern_for(kind) {
    if (kind == "email")      return "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z][A-Za-z]+"
    if (kind == "card")       return "[0-9]+([ -][0-9]+)*"
    if (kind == "ssn")        return "[0-9][0-9][0-9][- ][0-9][0-9][- ][0-9][0-9][0-9][0-9]"
    if (kind == "us_phone")   return "([+]?1[-. ]?)?([(][0-9][0-9][0-9][)] ?|[0-9][0-9][0-9][-. ])[0-9][0-9][0-9][-. ][0-9][0-9][0-9][0-9]"
    if (kind == "intl_phone") return "[+][0-9][0-9 .-]*[0-9]"
    if (kind == "bare")       return "[0-9]+"
}

function scan(line, kind,    re, off, rest, rs, rl) {
    re = pattern_for(kind)
    off = 0
    rest = line
    while (match(rest, re)) {
        rs = RSTART + off
        rl = RLENGTH
        if (kind == "card") card_run(line, rs, rl)
        else consider(line, kind, rs, rl)
        off = rs + rl - 1
        rest = substr(line, off + 1)
    }
}

function consider(line, kind, rs, rl,    val, prev, next_c, a, digits, cut) {
    val = substr(line, rs, rl)
    prev = charat(line, rs - 1)
    next_c = substr(line, rs + rl, 1)

    if (kind == "ssn") {
        if (prev ~ /[0-9A-Za-z-]/ || next_c ~ /[0-9A-Za-z]/) return
        if (substr(val, 4, 1) != substr(val, 7, 1)) return
        a = substr(val, 1, 3)
        if (a == "000" || a == "666" || a ~ /^9/) return
        if (substr(val, 5, 2) == "00" || substr(val, 8, 4) == "0000") return
    } else if (kind == "bare") {
        # A bare run of exactly 9 digits counts as a Social Security number, 10 as a phone number.
        if (rl != 9 && rl != 10) return
        if (prev ~ /[A-Za-z]/ || next_c ~ /[A-Za-z]/) return
        # Not part of a decimal number like 3.1415926535.
        if (prev == "." && charat(line, rs - 2) ~ /[0-9]/) return
        if (next_c == "." && substr(line, rs + rl + 1, 1) ~ /[0-9]/) return
        kind = (rl == 9) ? "ssn_bare" : "phone_bare"
    } else if (kind == "us_phone") {
        if (prev ~ /[0-9A-Za-z]/ || next_c ~ /[0-9]/) return
    } else if (kind == "intl_phone") {
        if (prev ~ /[0-9A-Za-z]/) return
        # Stop at the first pair of non-digits ("0958. 3 items" -> "0958").
        if (match(val, /[^0-9][^0-9]/)) val = substr(val, 1, RSTART - 1)
        sub(/[^0-9]+$/, "", val)
        rl = length(val)
        digits = val
        gsub(/[^0-9]/, "", digits)
        if (length(digits) < 8 || length(digits) > 15) return
    }
    record(kind, val, rs, rl)
}

# A run of digit groups separated by single spaces or dashes. Looks for card numbers inside it.
function card_run(line, rs, rl,    run, g, G, S, a, b, i, digits, start, len, ok) {
    if (charat(line, rs - 1) ~ /[A-Za-z]/ || substr(line, rs + rl, 1) ~ /[A-Za-z]/) return
    run = substr(line, rs, rl)
    g = split(run, G, /[ -]/)
    if (g == 1 && (rl < 13 || rl > 19)) return
    # Start offset of each group within the run.
    S[1] = 0
    for (i = 2; i <= g; i++) S[i] = S[i - 1] + length(G[i - 1]) + 1
    a = 1
    while (a <= g) {
        ok = 0
        for (b = g; b >= a; b--) {
            if (!card_shape(G, a, b)) continue
            digits = ""
            for (i = a; i <= b; i++) digits = digits G[i]
            if (length(digits) < 13 || length(digits) > 19) continue
            if (substr(digits, 1, 1) !~ /[2-6]/) continue
            if (!luhn(digits)) continue
            start = rs + S[a]
            len = S[b] + length(G[b]) - S[a]
            record("card", digits, start, len)
            ok = 1
            break
        }
        a = ok ? b + 1 : a + 1
    }
}

# Card numbers are written as one block, as groups of 4 (last group may be shorter),
# or Amex/Diners style 4-6-5 / 4-6-4. Phone-style groups of 3 never count.
function card_shape(G, a, b,    i) {
    if (a == b) return 1
    if (b - a == 2 && length(G[a]) == 4 && length(G[a + 1]) == 6 && (length(G[b]) == 5 || length(G[b]) == 4)) return 1
    for (i = a; i < b; i++) if (length(G[i]) != 4) return 0
    return length(G[b]) >= 1 && length(G[b]) <= 4
}

# Awks disagree about substr(s, 0, 1), so never ask for position 0.
function charat(s, i) { return i < 1 ? "" : substr(s, i, 1) }

function luhn(d,    sum, i, n, alt) {
    sum = 0
    alt = 0
    for (i = length(d); i >= 1; i--) {
        n = substr(d, i, 1) + 0
        if (alt) { n *= 2; if (n > 9) n -= 9 }
        sum += n
        alt = !alt
    }
    return sum % 10 == 0
}

function record(kind, val, rs, rl,    label, shown) {
    if (kind == "email") { label = "email"; shown = val }
    else if (kind == "card") { label = "card number"; shown = substr(val, 1, 4) " …" substr(val, length(val) - 3) }
    else if (kind == "ssn") { label = "Social Security number"; shown = "…-" substr(val, 8, 4) }
    else if (kind == "ssn_bare") { label = "Social Security number"; shown = "…" substr(val, 6, 4) }
    else { label = "phone number"; shown = val }
    record_as(label, shown, rs, rl)
}

# Adds a finding unless its text overlaps one already found on this line.
function record_as(label, shown, rs, rl,    i, key) {
    for (i = rs; i < rs + rl; i++) if (i in COVER) return
    for (i = rs; i < rs + rl; i++) COVER[i] = 1
    key = label "\t" shown
    if (key in SEEN) return
    SEEN[key] = 1
    FOUND[++NF_COUNT] = key
}

# ---------- secrets ----------
# Run before the personal-info checks, so digits inside a secret aren't also
# reported as a phone or card number. The warning never shows a whole secret.

function check_secrets(line,    lc) {
    lc = tolower(line)
    if (index(line, "-----BEGIN ")) private_keys(line)
    known_tokens(line)
    if (index(lc, "://")) url_passwords(line, lc)
    if (index(lc, "bearer") || index(lc, "authorization")) auth_headers(line, lc)
    if (has_any(lc, "pass|pwd|secret|token|key")) settings(line, lc)
}

# Every non-overlapping match of re in s, into MS[] (start) and ML[] (length).
function find_all(s, re,    n, off, rest) {
    n = 0
    off = 0
    rest = s
    while (match(rest, re)) {
        n++
        MS[n] = RSTART + off
        ML[n] = RLENGTH
        off = off + RSTART + RLENGTH - 1
        if (RLENGTH == 0) off++
        rest = substr(s, off + 1)
    }
    return n
}

function private_keys(line,    n, k, v) {
    n = find_all(line, "-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----")
    for (k = 1; k <= n; k++) {
        v = substr(line, MS[k] + 5, ML[k] - 10)
        record_as("private key", v, MS[k], ML[k])
    }
}

function token_formats() {
    if (NTOK) return
    # fixed text that must appear (| = either), regex, shortest, longest, label, characters to show
    tok("AKIA|ASIA",   "(AKIA|ASIA)[A-Z0-9]+",                          20, 20,   "AWS access key", 4)
    tok("gh",          "gh[pousr]_[A-Za-z0-9]+",                        40, 255,  "GitHub token", 4)
    tok("github_pat_", "github_pat_[A-Za-z0-9_]+",                      40, 255,  "GitHub token", 11)
    tok("glpat-",      "glpat-[A-Za-z0-9_-]+",                          26, 255,  "GitLab token", 6)
    tok("xox",         "xox[abposr]-[A-Za-z0-9-]+",                     15, 255,  "Slack token", 5)
    tok("k_live_|k_test_", "[sr]k_(live|test)_[A-Za-z0-9]+",            20, 255,  "Stripe key", 8)
    tok("sk-ant-",     "sk-ant-[A-Za-z0-9_-]+",                         30, 255,  "Anthropic API key", 7)
    tok("sk-",         "sk-[A-Za-z0-9_-]+",                             30, 255,  "OpenAI API key", 3)
    tok("AIza",        "AIza[A-Za-z0-9_-]+",                            39, 39,   "Google API key", 4)
    tok("npm_",        "npm_[A-Za-z0-9]+",                              40, 40,   "npm token", 4)
    tok("SG.",         "SG[.][A-Za-z0-9_-]+[.][A-Za-z0-9_-]+",          50, 100,  "SendGrid key", 3)
    tok("eyJ",         "eyJ[A-Za-z0-9_-]+[.]eyJ[A-Za-z0-9_-]+[.][A-Za-z0-9_-]+", 30, 100000, "access token (JWT)", 3)
}

function tok(hint, re, lo, hi, label, show) {
    NTOK++
    THINT[NTOK] = hint; TRE[NTOK] = re; TLO[NTOK] = lo; THI[NTOK] = hi; TLAB[NTOK] = label; TSHOW[NTOK] = show
}

function known_tokens(line,    t, n, k, v, rs, rl) {
    token_formats()
    for (t = 1; t <= NTOK; t++) {
        if (!has_any(line, THINT[t])) continue
        n = find_all(line, TRE[t])
        for (k = 1; k <= n; k++) {
            rs = MS[k]; rl = ML[k]
            v = substr(line, rs, rl)
            if (rl < TLO[t] || rl > THI[t]) continue
            if (charat(line, rs - 1) ~ /[A-Za-z0-9]/ || substr(line, rs + rl, 1) ~ /[A-Za-z0-9]/) continue
            # Real keys are random: they mix digits and letters. Skips "sk-some-long-slug-of-words".
            if (v !~ /[0-9]/ || substr(v, TSHOW[t] + 1) !~ /[A-Za-z]/) continue
            record_as(TLAB[t], substr(v, 1, TSHOW[t]) "…", rs, rl)
        }
    }
}

function has_any(s, hints,    n, H, i) {
    n = split(hints, H, "|")
    for (i = 1; i <= n; i++) if (index(s, H[i])) return 1
    return 0
}

# https://user:password@host
function url_passwords(line, lc,    n, k, v, c, at, pw) {
    n = find_all(lc, "[a-z][a-z0-9+.-]*://[^/ :@]+:[^/ @]+@")
    for (k = 1; k <= n; k++) {
        v = substr(line, MS[k], ML[k])
        c = index(substr(v, index(v, "://") + 3), ":") + index(v, "://") + 2
        pw = substr(v, c + 1, length(v) - c - 1)
        if (is_not_a_secret(pw, 1)) continue
        record_as("password in a web address", substr(v, 1, c) "…@", MS[k], ML[k])
    }
}

function auth_headers(line, lc,    n, k, v, sp) {
    n = find_all(lc, "authorization[^a-z0-9]*(bearer|basic|token) +[a-z0-9._~+/=-]+")
    for (k = 1; k <= n; k++) auth_value(line, MS[k], ML[k], 8)
    n = find_all(lc, "bearer +[a-z0-9._~+/=-]+")
    for (k = 1; k <= n; k++) auth_value(line, MS[k], ML[k], 16)
}

function auth_value(line, rs, rl, minlen,    v, value) {
    v = substr(line, rs, rl)
    value = v
    sub(/^.* /, "", value)
    if (length(value) < minlen || is_not_a_secret(value, 0)) return
    if (minlen > 8 && value !~ /[0-9]/) return
    record_as("access token", substr(v, 1, length(v) - length(value)) "…", rs, rl)
}

# Settings such as password=..., "api_key": "...", --token ..., SECRET_KEY: ...
function settings(line, lc,    n, k, ks, ke, key, p, c, spaced, q, vs, ve, value, kind) {
    n = find_all(lc, "[a-z0-9_.-]*(password|passwd|pwd|passphrase|secret|token|(api|access|private|secret|auth|signing|encryption)[_.-]?key)")
    for (k = 1; k <= n; k++) {
        ks = MS[k]; ke = ks + ML[k]
        key = substr(line, ks, ML[k])
        # The name must end here: "passwords", "max_tokens" and "tokenizer" don't count.
        if (substr(lc, ke, 1) !~ /^([ \t:="'`]|)$/ || ke > length(lc)) continue
        p = ke
        if (substr(line, p, 1) ~ /["'`]/) p++
        spaced = 0
        while (substr(line, p, 1) ~ /[ \t]/) { p++; spaced = 1 }
        c = substr(line, p, 1)
        if (c == ":" && substr(line, p + 1, 1) == "=") p += 2
        else if (c == ":" || c == "=") {
            if (substr(line, p + 1, 1) == "=") continue      # == comparison
            p++
        } else if (!(spaced && key ~ /^-/)) continue         # --token VALUE
        while (substr(line, p, 1) ~ /[ \t]/) p++
        q = substr(line, p, 1)
        if (q ~ /["'`]/) {
            vs = p + 1
            ve = index(substr(line, vs), q)
            ve = ve ? vs + ve - 1 : length(line) + 1
        } else {
            vs = p
            ve = vs
            while (ve <= length(line) && substr(line, ve, 1) !~ /[ \t&,;"'`)}\]]/) ve++
        }
        value = substr(line, vs, ve - vs)
        kind = key_kind(tolower(key))
        if (is_not_a_secret(value, kind == "password")) continue
        record_as(kind, key "=…", ks, ve - ks)
    }
}

function key_kind(k) {
    if (k ~ /(password|passwd|pwd|passphrase)$/) return "password"
    if (k ~ /token$/) return "token"
    if (k ~ /secret$/) return "secret"
    return "key"
}

# Values that are code, variables, types or placeholders rather than a real secret.
function is_not_a_secret(v, is_password,    lv) {
    lv = tolower(v)
    if (length(v) < (is_password ? 6 : 8)) return 1
    if (v ~ /^[$%{<(\[@\/~*.]/) return 1
    if (v ~ /[][{}()<>]/) return 1
    if (lv ~ /^(function|lambda|async|await|new|this|self|return|yield|class|def|require|import|static|const|let|var)$/) return 1
    if (lv ~ /^(string|str|int|integer|number|bool|boolean|any|text|varchar|char|bytes|none|null|nil|undefined|true|false|optional)$/) return 1
    if (lv ~ /(your|example|placeholder|redacted|dummy|sample|fake|replace_?me|xxx|[*][*][*]|[.][.][.])/) return 1
    if (lv ~ /(process[.]env|os[.]environ|getenv|secrets[.])/) return 1
    if (same_char(v)) return 1
    # A dotted name like config.apiKey or req.body.password.
    if (lv ~ /^[a-z_$][a-z0-9_$]*([.][a-z_$][a-z0-9_$]*)+$/) return 1
    # Another variable's name, like DB_PASSWORD or hashed_password.
    if (lv ~ /^[a-z_]+$/ && lv ~ /(password|passwd|token|secret|key)/) return 1
    return 0
}

function same_char(v,    i, c) {
    c = substr(v, 1, 1)
    for (i = 2; i <= length(v); i++) if (substr(v, i, 1) != c) return 0
    return 1
}
