# ADR-0008: Collection keys match case-insensitively

- **Status:** proposed
- **Date:** 2026-10-06
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

- ModSecurity v2 compares a selector against member names with `strcasecmp`
  (`apache2/re_variables.c`, every `var_*_generate` for `ARGS`, `REQUEST_HEADERS`,
  `REQUEST_COOKIES`, `TX`, …).
- libmodsecurity v3 stores members in an unordered multimap with a lower-casing hash and
  equality (`headers/modsecurity/anchored_set_variable.h`, `MyHash`, `MyEqual`; `TX` in
  `src/collection/backend/in_memory-per_process.h`, the same pair).
- Coraza 3.8.1 lower-cases keys on storage and lookup (`internal/collections/map.go`)
  unless built with `coraza.rule.case_sensitive_args_keys` (Coraza ADR-0016), in which case
  `ARGS` keys are compared exactly; Coraza ADR-0015 added a case-sensitive map type for
  internal use and deferred switching the default to v4. `TX` is case-insensitive in
  every build.
- Regex selectors are case-insensitive in all three engines: v2 compiles them with
  `PCRE2_CASELESS` (`apache2/re_variables.c`, `var_generic_list_validate`), v3 with
  `ignoreCase` (`src/variables/variable.h`, `VariableRegex`), and Coraza lower-cases the
  pattern and matches it against the lower-cased names (`internal/corazawaf/rule.go`,
  `AddVariable`), which also changes upper-case escapes (`\D` becomes `\d`). The exception
  is Coraza's `ARGS` family: `caseSensitiveVariable` keeps the pattern as written in every
  build while the default build stores the names lower-cased, so an upper-case pattern
  never matches an argument.
- The name an engine reports keeps the first spelling written in v2 and v3 (`TX:Foo`) and
  is lower-cased in Coraza (`TX:foo`).

OWASP CRS writes `%{tx.anomaly_score}` and `TX:ANOMALY_SCORE` interchangeably (hundreds of
occurrences of each spelling) and selects headers as `REQUEST_HEADERS:Content-Type`.

Revised 2026-11-09: the first version said a regex selector was case-sensitive unless the
expression said otherwise. Running the three reference adapters with `TX` members showed
v2.9.15, libmodsecurity v3.0.17 and Coraza v3.8.1 all match regex selectors
case-insensitively (Coraza except on `ARGS*`), so the decision now says so,
`tests/engine/variables/key-case.yaml` covers `TX`, and
`tests/engine/variables/key-case-args-regex.yaml` covers `ARGS`.

## Decision

Member names in every collection, `TX` included, are matched against key selectors, macro
keys and `setvar` names case-insensitively, so names that differ only in case denote one
member. A regex selector is applied to member names case-insensitively too. The case in
which an engine reports a member's name (`MATCHED_VAR_NAME`, `*_NAMES`) is not specified.
Normative text: `spec/05-variables.md#collection-keys`. The Coraza case-sensitive build is
non-conforming.

## Options considered

- Case-sensitive keys: HTTP header names are case-insensitive by RFC 9110 and CRS mixes
  `TX` key spellings; rejected.
- Per-collection sensitivity (Coraza's own stated ideal): no engine implements it and no
  ruleset needs it; rejected for now.
- Case-insensitive everywhere (chosen).

## Consequences

- For ModSecurity: no change.
- For Coraza: keep the default; the build tag stays opt-in and documented as
  non-conforming. Regex selectors on `ARGS*` must match case-insensitively in the default
  build (lower-case the pattern there too, as for every other collection); until then
  `key-case-args-regex.yaml` is a known gap.
- For rule authors: names that differ only in case cannot be distinguished by any
  selector; a portable regex selector avoids upper-case escapes (`\D`, `\S`, `\W`, `\B`),
  which Coraza lower-cases, and compares reported names case-insensitively.

## Tests

- `tests/engine/variables/key-case.yaml`
- `tests/engine/variables/key-case-args-regex.yaml`

## References

- `spec/05-variables.md#collection-keys`
- Coraza ADR-0015 and Coraza ADR-0016 in `corazawaf/coraza/docs/adr`
