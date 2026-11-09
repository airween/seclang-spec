# ADR-0004: Canonical names and required aliases

- **Status:** proposed
- **Date:** 2026-10-06
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

Several operators, transformations and directive values have more than one spelling:

- ModSecurity v2 registers `normalisePath`/`normalizePath` and `normalisePathWin`/
  `normalizePathWin` (`apache2/re_tfns.c`), `pmf`/`pmFromFile` and `ipmatchf`/
  `ipmatchFromFile` (`apache2/re_operators.c`), and the `sanitise*`/`sanitize*` action
  pairs (`apache2/re_actions.c`).
- libmodsecurity v3's scanner accepts `normalisePath|normalizePath`, `@ipMatchF|
  @ipMatchFromFile`, `@pmf|@pmFromFile`, and `Parallel|Concurrent` for `SecAuditLogType`
  (`src/parser/seclang-scanner.ll`).
- Coraza registers `normalisePath`/`normalizePath` (+Win) in
  `internal/transformations/transformations.go`, and added `pmf` and `ipMatchF` one at a
  time in Coraza ADR-0026 and Coraza ADR-0027 after rulesets in the wild failed to load.
- Coraza accepts `HTTPS` and `Syslog` for `SecAuditLogType`; libmodsecurity v3 accepts
  `https`; ModSecurity v2 accepts neither.

Without a fixed list, every engine discovers aliases by breaking on someone's ruleset.

## Decision

Canonical names and the aliases every engine MUST accept:

| Canonical | Required alias | Kind |
|---|---|---|
| `normalisePath` | `normalizePath` | transformation |
| `normalisePathWin` | `normalizePathWin` | transformation |
| `pmFromFile` | `pmf` | operator |
| `ipMatchFromFile` | `ipMatchF` | operator |

Spellings that differ only in case are not aliases; they are the same name (ADR-0002).
v2's `sanitise*` spellings are not aliases: only `sanitize*` is specified (ADR-0033).
`Parallel`, `https` and
`Syslog`/`HTTPS` for `SecAuditLogType` are Engine-specific values. No new alias may be
introduced without amending this ADR; engines SHOULD log the canonical spelling.

## Options considered

- Canonical only, no aliases: breaks every ruleset using `normalizePath` or `pmf`,
  including historical CRS versions; rejected.
- Accept every spelling any engine ever had: makes `sanitize*` Core for engines without
  the feature; rejected.
- Fixed short list (chosen): what all three already do, written down.

## Consequences

- For ModSecurity: no change.
- For Coraza: no change today; future aliases need an ADR here, not a local one.
- For rule authors: the four aliases are safe; prefer the canonical spelling in new
  rules.

## Tests

- `tests/engine/grammar/name-aliases.yaml`

## References

- `spec/02-grammar.md#operator`, `spec/07-transformations.md`
- Coraza ADR-0026 and Coraza ADR-0027 in `corazawaf/coraza/docs/adr`
