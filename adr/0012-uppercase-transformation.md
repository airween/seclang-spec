# ADR-0012: `uppercase` is promoted to Core

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Extension

## Context

`t:uppercase` exists in libmodsecurity v3 (`src/actions/transformations/upper_case.cc`)
and Coraza (added in Coraza ADR-0007 to match the documented behaviour) but not in
ModSecurity v2 (`apache2/re_tfns.c` registers `lowercase` only). It is the mirror image
of `lowercase`, which is Core, and trivial to implement.

## Decision

`uppercase` is Core. ModSecurity v2 is listed in `compat/known-gaps.md` for it. This is
the one Core feature that an engine lacks by construction; the design document seeded the
decision and the Phase 3 plan review confirmed it.

## Options considered

- Extended (two of three engines): consistent with the status rule but leaves a trivial
  asymmetry in the Core transformation set; rejected by the plan review.
- Core (chosen).

## Consequences

- For ModSecurity v2: add `uppercase` (a few lines next to `lowercase`).
- For rule authors: `t:uppercase` is portable once v2 ships it.

## Tests

- `tests/unit/transformations/uppercase-extra.json`

## References

- `spec/07-transformations.md#uppercase`
- Coraza ADR-0007 in `corazawaf/coraza/docs/adr`
