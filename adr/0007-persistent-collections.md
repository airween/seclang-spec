# ADR-0007: Persistent collections are Extended

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

The `IP`, `SESSION`, `USER`, `GLOBAL` and `RESOURCE` collections, the scalars
`SESSIONID`, `USERID` and `WEBAPPID`, the actions `initcol`, `setsid`, `setuid`,
`setrsc` and `expirevar` on those collections, and the directives `SecDataDir` and
`SecCollectionTimeout` together implement state that outlives one transaction.

- ModSecurity v2 implements them with SDBM files under `SecDataDir`
  (`apache2/persist_dbm.c`).
- libmodsecurity v3 implements them in memory per process, with an optional LMDB backend;
  `SecDataDir` is parsed and ignored (`seclang-parser.yy`, error disabled "to avoid
  breaking default installations").
- Coraza 3.8.1 has no persistent collections: the variable names are unknown to its
  parser and `initcol`, `setsid`, `setuid`, `setrsc` are not registered actions.

OWASP CRS v4 core rules do not use them; the DoS-protection and IP-reputation plugins do.

## Decision

Persistent collections are one Extended feature, `05-variables.md#persistent-collections`.
Engine-tier profiles that need them list that anchor in `requires:`. Their semantics
follow the ModSecurity reference manual until two engines implement them, at which point
a Phase 4 task specifies them fully. `initcol`, `setsid`, `setuid` and `setrsc` are
Extended actions for the same reason.

## Options considered

- Core: makes Coraza non-conforming on a feature no Core ruleset needs; rejected.
- Deprecated: two engines implement and CRS plugins rely on them; rejected.
- Extended (chosen).

## Consequences

- For Coraza: no obligation; implementing them later promotes nothing automatically.
- For CRS plugin authors: plugins using `IP` or `GLOBAL` declare the Extended feature.

## Tests

- `tests/engine/variables/persistent-collections.yaml` (carries `requires:`, so engines
  without the feature skip it)

## References

- `spec/05-variables.md#persistent-collections`, `spec/04-directives.md#secdatadir`
