# ADR-0027: `@rx` is compiled dot-all; line anchors need `(?m)`

- **Status:** accepted
- **Date:** 2026-10-08
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

Each engine compiles the `@rx` pattern with options the rule author never writes:

- ModSecurity v2 (`apache2/re_operators.c`, `msre_op_rx_param_init`): `PCRE_DOTALL |
  PCRE_DOLLAR_ENDONLY`. `.` matches a newline; `^` and `$` match only at the subject's
  start and end, `$` not even before a final newline.
- libmodsecurity v3.0.16 (`src/utils/regex.cc`, `Regex::Regex`): `PCRE2_DOTALL |
  PCRE2_MULTILINE`. `.` matches a newline; `^` and `$` also match at every inner line
  boundary.
- Coraza v3.8.1 (`internal/operators/rx.go`, `newRX`): the pattern is prefixed with
  `(?sm)` by default (`internal/operators/multilineregex_default.go`); the
  `coraza.rule.no_regex_multiline` build tag (`internal/operators/multilineregex.go`)
  makes it `(?s)`.

Dot-all is shared. Multiline is not: against a value that contains a newline, `^b` on
`a\nb` fails in v2 and matches in v3 and in a default Coraza build. OWASP CRS writes
`(?m)` explicitly where it needs line anchors, so the ruleset in widest use already lives
in the intersection. The Lean model surfaced the gap when it defaulted `.` to not match a
newline (stage 4 review).

## Decision

`@rx`, the implicit regex operator, regex selectors and every other regular expression in
a configuration MUST be matched in dot-all mode: `.` matches every byte including the
newline. Whether `^` and `$` match at inner line boundaries when the pattern does not say
`(?m)` is **not specified**; portable rules MUST write `(?m)` when they need line anchors
and MUST NOT rely on `^`/`$` failing or succeeding at inner newlines without it. `(?-s)`
is outside the Core syntax. Normative text: `spec/06-operators.md#rx`.

## Options considered

- v2 behaviour as Core (anchors at the subject ends only): makes libmodsecurity and
  default Coraza builds non-conforming on `@rx`; rejected.
- Multiline as Core: makes ModSecurity v2 non-conforming and changes the meaning of
  `^`/`$` in every existing v2 rule; rejected.
- Dot-all Core, line anchors unspecified without `(?m)` (chosen): what CRS already does;
  costs no engine anything. The reference model follows the v2 reading because it is the
  stricter one (fewer matches).

## Consequences

- For ModSecurity v2: none. For libmodsecurity v3: none, it is already dot-all.
- For Coraza: none; a build with `coraza.rule.no_regex_multiline` stays conforming.
- For rule authors: write `(?m)` for line anchors; never write a pattern whose result
  depends on `$` matching before a trailing newline.
- For this repository: `formal/SecLang/Regex.lean` compiles patterns with `dotAll` and
  matches `$` only at the subject end unless `(?m)`.

## Tests

- `tests/engine/operators/rx-dotall.yaml` (dot-all, Core)
- `tests/unit/operators/rx.json`

The unspecified part (`^`/`$` without `(?m)` against a value containing a newline) is
deliberately untested: a Core test cannot assert behaviour the engines do not share.

## References

- `spec/06-operators.md#rx`, ADR-0018
- https://github.com/corazawaf/coraza/pull/876 (multiline default discussion)
