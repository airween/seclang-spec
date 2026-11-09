# ADR-0023: Reference adapters live in this repository

- **Status:** accepted
- **Date:** 2026-10-07
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

The design assumed that `tests/` would stay data-only and that each engine would write
its own adapter elsewhere. Three review rounds showed the cost of that: the reviewer who
actually ran the profiles against Coraza (with a throwaway Go harness) found defects in
one run that source reading had missed in three. Until an adapter runs the data, every
row of `compat/known-gaps.md` is a prediction.

## Decision

Reference adapters live under `adapters/<engine>/` in this repository and are run by CI.
The test data stays engine-neutral and remains the contract (ADR-0003); an adapter is a
consumer of it, never its definition. An engine project MAY keep its own adapter instead;
the reference one exists so the specification can be checked without waiting. A
reference adapter MUST treat `compat/known-gaps.md` as its expected-failure list and MUST
fail when a listed file passes, so that the table cannot go stale. The first reference
adapters are `adapters/coraza` (Go, Coraza v3.8.1 pinned) and `adapters/libmodsecurity` (Python over
the C API, libmodsecurity v3.0.16 built by CI).

## Options considered

- Keep the repository runner-free: the table stays unverified; rejected by experience.
- Adapters in the engine repositories only: right owners, but cross-repository iteration
  and no CI signal here; allowed as an alternative, not required.
- Reference adapters here (chosen).

## Consequences

- Go and a Coraza dependency enter the repository; CI gains a Go job.
- Known-gaps rows for Coraza and libmodsecurity v3 are verified; rows for ModSecurity v2
  remain predictions until an adapter exists for it.
- CI builds libmodsecurity from source (cached by tag); that adapter reads matched rules
  from the engine debug log because the C API omits `nolog` matches. Its first run added
  eight v3 rows, removed two predictions, moved `SecRequestBodyInMemoryLimit` to
  Deprecated and produced ADR-0024.
- The first Coraza run corrected the specification in three places (ctl:ruleEngine
  timing, skipAfter scope, quoted-argument escapes) and the review of that run corrected
  the escape rule again for the ModSecurity branches; that loop is what this ADR
  institutionalises.

## Tests

- `adapters/coraza/conformance_test.go` (`TestEngine`, `TestUnit`)
- `adapters/libmodsecurity/test_conformance.py` (`TestEngine`, `TestUnit`)

## References

- `adapters/coraza/README.md`, `adapters/libmodsecurity/README.md`, `compat/known-gaps.md`, ADR-0003
