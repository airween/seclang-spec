# ADR-0002: Directive, operator, action and transformation names match case-insensitively

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

- ModSecurity v2: directives are Apache configuration commands and Apache matches them
  case-insensitively. Actions, operators, transformations and variables are looked up
  in APR tables (`apache2/re.c`, `apr_table_get`), whose keys are case-insensitive.
- libmodsecurity v3: the Flex scanner (`src/parser/seclang-scanner.ll`) wraps every
  directive, action, operator and transformation token in `(?i:...)`.
- Coraza 3.8.1: directive names are lowercased before lookup
  (`internal/seclang/directivesmap.gen.go`), action names are lowercased in
  `internal/actions/actions.go` `Get`, transformation names are lowercased in
  `internal/transformations/transformations.go` `GetTransformation`, but operator names
  are looked up verbatim in `internal/operators/operators.go` `Get`. `@IPMATCH` or
  `@ipmatch` (the ModSecurity v2 spelling) fails to load in Coraza.

Rulesets in the wild mix spellings: CRS uses `@ipMatch`, older third-party rules use
`@ipmatch` and `@pmf`.

## Decision

Engines MUST match directive names, operator names, action names, transformation names
and `ctl:` option names case-insensitively. The canonical spelling is the mixed-case
form from the ModSecurity reference manual; engines SHOULD use it in logs.

Variable and collection names, and collection keys, are out of scope here (ADR-0008).

## Options considered

- Case-insensitive everywhere (chosen): matches two of three engines and all
  historical documentation; costs Coraza one `strings.ToLower` in operator lookup.
- Case-sensitive canonical names only: would break existing rulesets on ModSecurity
  users who migrate; rejected.
- Case-insensitive for directives only: leaves the actual observed incompatibility in
  place; rejected.

## Consequences

- For ModSecurity: no change.
- For Coraza: lowercase the operator name in both `operators.Register` and
  `operators.Get`, so plugin operators registered with mixed case keep working.
- For rule authors: spelling variants of the same name are safe; distinct names that
  differ only in case cannot exist, so no engine may introduce one.

## Tests

- `tests/engine/lexical/case-insensitive-names.yaml`

## References

- `spec/01-lexical.md#name-matching`
- Coraza ADR-0026 (`pmf` alias) and Coraza ADR-0027 (`ipMatchF` alias) in
  `corazawaf/coraza/docs/adr`, which added spelling aliases one at a time.
