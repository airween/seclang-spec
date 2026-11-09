# ADR-0009: Strict per-phase evaluation is normative; early evaluation must be invisible

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

`03-processing-model.md#phases` defines five phases and says a rule runs in its declared
phase against the data available then. Coraza offers an optional mode
(`coraza.rule.multiphase_evaluation` build tag, `internal/corazawaf/rule.go`) that
evaluates a rule's variables in the earliest phase in which each becomes available, so
that, for example, a phase 2 rule on `ARGS` can block on `ARGS_GET` before the body is
read. ModSecurity v2 and libmodsecurity v3 have no such mode. The question is whether the
specification should describe the strict model only or also admit the optimisation.

## Decision

The strict model is normative: every observable effect of a rule (its `triggered`
status, interruptions, `MATCHED_VAR*`, `TX` changes, `ctl` effects, logging) MUST occur in
the rule's declared phase and in configuration order within it. An engine MAY evaluate
earlier internally only when the result is observationally identical for every test in
this repository and for the ordering guarantees in `03-processing-model.md`; a mode that
can be told apart is non-conforming while enabled.

## Options considered

- Specify multiphase evaluation: no second engine implements it and it changes when
  interruptions happen; rejected.
- Forbid it outright: an unobservable optimisation is none of the specification's
  business; rejected.
- Permit if invisible (chosen).

## Consequences

- For Coraza: the default build conforms; the multiphase build must pass the same tests
  with the same `triggered_rules` and interruptions.
- For rule authors: none.

## Tests

- `tests/engine/processing/phases.yaml`
- `tests/engine/processing/ctl-timing.yaml`

## References

- `spec/03-processing-model.md#phases`
