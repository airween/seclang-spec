# ADR-0037: `&` applies to every variable and counts a scalar as 1

- **Status:** proposed
- **Date:** 2026-11-11
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

`&` replaces the values a variable selects by their count (`02-grammar.md#variable-list`).
On a collection that is the number of selected members. On a scalar, which always holds
exactly one value (`05-variables.md#collection-keys`), the engines disagree on whether
`&` is allowed at all.

- ModSecurity v2 (v2.9.15): `&` on a variable registered as `VAR_SIMPLE` is a
  configuration error, "The & modificator does not apply to non-collection variables."
  (`apache2/re.c`). The check follows the registration type, not the variable's meaning:
  `REQUEST_BODY` is registered as `VAR_LIST` (`apache2/re_variables.c`), so
  `&REQUEST_BODY` loads while `&REQUEST_URI`, `&REQUEST_BODY_LENGTH` and
  `&REQBODY_PROCESSOR` do not. Checked with `apache2 -t` in the reference adapter's image.
- libmodsecurity v3 (v3.0.17): `VariableModificatorCount` (`src/variables/variable.h`)
  wraps any variable the parser accepts (`src/parser/seclang-parser.yy`) and counts the
  values it yields: 1 for a scalar.
- Coraza (v3.8.1): `Transaction.GetField` (`internal/corazawaf/transaction.go`) replaces
  the matches by `len(matches)` when `rv.Count` is set, for any variable: 1 for a scalar.

Raised in `coreruleset/secrules_parsing` issue 73, where a CRS plugin exclusion used `&`
on a scalar; the CRS and Coraza maintainers there agreed that `&` means "how many values
does this select" for every variable, as it does on a collection.

## Decision

`&` MAY prefix any variable. On a scalar it yields 1, whether or not the engine has set
the scalar yet, since a scalar always holds one value (`05-variables.md#collection-keys`).
`&` on a scalar MUST NOT be a configuration error.

## Options considered

- **Count every variable; a scalar counts 1 (chosen).** What v3 and Coraza do, and the
  semantics `&` already has on collections, so a rule can test any variable the same
  way. Costs v2 a change.
- **Make `&` on a scalar a configuration error.** v2's behaviour, but v2 applies it by
  registration type, so a portable version would first have to define which variables
  are scalars for this purpose; v3 and Coraza would start rejecting rules they load
  today. Rejected.
- **Leave it unspecified.** A ruleset that loads on v3 and Coraza fails to load on v2,
  which stops the whole configuration. Rejected.

## Consequences

- For ModSecurity v2: drop the `VAR_SIMPLE` check in `apache2/re.c` and return a count
  of 1. A migration path proposed in issue 73: accept the new behaviour behind a
  compile-time flag and warn when a rule depends on the old error, then remove the flag.
- For libmodsecurity v3 and Coraza: no change.
- For rule authors: until v2 changes, `&` on a scalar stops a v2 configuration from
  loading; rules meant for v2 test the scalar's value instead.

## Tests

- `tests/engine/variables/count-scalar.yaml`

## References

- https://github.com/coreruleset/secrules_parsing/issues/73
- `02-grammar.md#variable-list`, `05-variables.md#collection-keys`
