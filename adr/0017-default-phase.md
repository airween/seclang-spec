# ADR-0017: The default phase is 2 and is never inherited

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

A rule may omit the `phase` action. What phase it then runs in:

- ModSecurity v2 (`apache2/re.c`, `actionset->phase = 2` when `NOT_SET`): phase 2, **but**
  a phase-less rule first inherits the phase of the current `SecDefaultAction`
  (`msre_actionset_merge`, `if (child->phase != NOT_SET) merged->phase = child->phase`),
  because v2 keeps one current default action set rather than one per phase.
- libmodsecurity v3 (`headers/modsecurity/rule.h`, `m_phase(RequestHeadersPhase)`):
  phase 1.
- Coraza 3.8.1 (`internal/corazawaf/rule.go`, `Phase_: 2`): phase 2; default actions are
  looked up by the rule's own phase (`rule_parser.go`).

The ModSecurity reference manual documents phase 2 as the default. OWASP CRS sets `phase`
on every rule, so the question only arises in hand-written rules.

## Decision

A rule without a `phase` action runs in phase 2. The phase is never taken from a
`SecDefaultAction`. Normative text: `spec/03-processing-model.md#phases`.

## Options considered

- Phase 1 (v3): contradicts the manual and the other two engines; rejected.
- Phase 2 with v2-style inheritance: makes the meaning of a rule depend on which
  `SecDefaultAction` precedes it; rejected.
- Phase 2, no inheritance (chosen): manual, Coraza, and v2 whenever no
  `SecDefaultAction` is in effect.

## Consequences

- For libmodsecurity v3: change the default to `RequestBodyPhase`
  (`default-phase.yaml` fails on v3 today).
- For ModSecurity v2: stop inheriting `phase` from the default action set.
- For rule authors: always write `phase:`; the tests in this repository do.

## Tests

- `tests/engine/processing/default-phase.yaml`

## References

- `spec/03-processing-model.md#phases`, ADR-0014
