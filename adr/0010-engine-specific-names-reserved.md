# ADR-0010: Engine-specific names are reserved

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

Each engine ships features the others do not: Coraza's `SecDataset`, `@pmFromDataset`,
`@ipMatchFromDataset`, `@restpath`, `@validateNid`, `SecRxPreFilter`,
`SecResponseBodyJsonDepthLimit`, `ctl:responseBodyProcessor`,
`ctl:forceResponseBodyVariable` and the `RESPONSE_ARGS`/`RES_BODY_*`/`JSON`/`ARGS_PATH`
variables; libmodsecurity v3's `@rxGlobal`, `@verifySVNR`, `SecAuditLogPrefix`,
`MSC_PCRE_*`, `STATUS`. The matrix lists them with status Engine-specific. Without a rule,
a second engine could reuse a name with different semantics and rulesets would silently
change meaning.

## Decision

A name with status Engine-specific is reserved for the engine that defined it. Another
engine MUST NOT define a feature with that name unless it implements the same semantics,
in which case the feature is promoted by an Extension ADR (as ADR-0012 did for
`uppercase`) and becomes Extended or Core. Engine-specific names are documented in
outline only; their semantics are the owning engine's documentation.

## Options considered

- Leave unlisted: collisions go unnoticed; rejected.
- Specify them fully: the specification would describe one engine's internals; rejected.
- Reserve and outline (chosen).

## Consequences

- For all engines: check the matrix before naming a new directive, operator, action,
  transformation or variable; new names need a matrix row and an index entry.

## Tests

None; a reservation is checked by review, not by a runner.

## References

- `compat/matrix.md`, `spec/00-conventions.md`
