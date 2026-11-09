# ADR-0018: Core regular-expression syntax is the RE2-compatible subset

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

- ModSecurity v2 compiles `@rx` with PCRE (`apache2/msc_pcre.c`).
- libmodsecurity v3 compiles with PCRE2 (`configure.ac`, `PROG_PCRE2`; PCRE only when
  explicitly requested).
- Coraza 3.8.1 compiles with Go's `regexp` package (`internal/operators/rx.go`), an RE2
  implementation: no lookaround, no backreferences, no possessive quantifiers, no `\K`,
  no recursion, guaranteed linear time.

The SecRules Test Set contains two `rx` cases using lookahead (`<\?(?!xml)`); Coraza's copy
of the corpus omits them. OWASP CRS v4 restricts itself to RE2-compatible syntax and
verifies this with `crs-toolchain`, so the largest ruleset in use already lives in the
intersection. `SecAuditLogRelevantStatus` in the two recommended configurations differs
for the same reason (Phase 2 review).

## Decision

The Core syntax of `@rx` (and of the implicit regex operator, regex selectors and every
other place a regular expression appears) is the subset accepted identically by PCRE,
PCRE2 and RE2, enumerated in `spec/06-operators.md#rx`. PCRE-only constructs are the
Extended feature `06-operators.md#rx-pcre-extensions`. A Core test MUST NOT use them.
Engines MAY implement more; rules that do are not portable.

## Options considered

- PCRE as Core: makes Coraza non-conforming on the most used operator and forbids a
  linear-time engine; rejected.
- RE2 subset as Core (chosen): what CRS already does; costs ModSecurity nothing.
- Per-engine dialects, unspecified: leaves every `@rx` rule's portability unknown;
  rejected.

## Consequences

- For ModSecurity: none.
- For Coraza: none.
- For rule authors: avoid lookaround and backreferences, or declare the Extended
  feature.
- For this repository: the two lookahead cases move to `rx-pcre-extra.json`.

## Tests

- `tests/unit/operators/rx.json` (Core subset)
- `tests/unit/operators/rx-pcre-extra.json` (Extended)
- `tests/engine/operators/rx-capture.yaml`

## References

- `spec/06-operators.md#rx`, `spec/06-operators.md#rx-pcre-extensions`
- https://github.com/google/re2/wiki/Syntax
