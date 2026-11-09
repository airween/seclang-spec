# ADR-0016: `skipAfter` scope ends with the phase

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

`skipAfter:LABEL` skips rules until a `SecMarker LABEL`. What happens when the marker is
not reached before the end of the current phase:

- ModSecurity v2 (`apache2/re.c`, `msre_ruleset_process_phase`): `skip_after` is a local
  variable of the per-phase loop, so the skip ends with the phase. The reference manual
  says the skip "works only within the current processing phase".
- libmodsecurity v3 (`Transaction::m_marker`, `src/rules_set.cc` `isInsideAMarker`): the
  marker is stored on the transaction and cleared only when a `SecMarker` with that name
  is evaluated, so an unreached skip continues into the next phases.
- Coraza 3.8.1 (`Transaction.SkipAfter`, `internal/corazawaf/rulegroup.go`): same as v3.

Markers are phase-less and all three engines evaluate every `SecMarker` in every phase,
so a marker placed anywhere later in the configuration is reached in the current phase
and clears the skip (verified for Coraza by `adapters/coraza`:
`skipafter-later-phase.yaml` passes). The engines differ only when no marker of that
name exists: v2 ends the skip with the phase, v3 and Coraza disable every remaining rule
of every later phase.

## Decision

An unreached `skipAfter` ends with the current phase. Rules of later phases MUST run
normally. `SecMarker` is phase-less and satisfies a `skipAfter` in any phase in which it
is encountered. Normative text: `spec/03-processing-model.md#flow-control`.

Since every marker is evaluated in every phase, a skip goes unreached exactly when no
`SecMarker LABEL` follows the rule in configuration order, which is known when the
configuration is loaded. An engine SHOULD then warn at load time, naming the rule and the
label, and MUST still load the configuration. The warning's wording and destination are
engine-specific. (Added 2026-11-09; no surveyed engine warns today: v2 ends the skip
silently, logging it only at debug level 9 in `msre_ruleset_process_phase`, and v3 and
Coraza carry it into later phases.)

## Options considered

- Transaction-wide skip (v3, Coraza): two engines agree, but the effect of a missing
  marker is to silently disable the WAF for the rest of the transaction; rejected.
- Per-phase skip (chosen): documented behaviour, v2 behaviour, and fail-safe.
- For the missing marker: a load error would break configurations that load in all three
  engines today; a runtime warning each time a phase ends with a skip pending reports the
  same cases on every matching transaction; a load-time warning (chosen) reports each
  once. SHOULD rather than MUST, because no engine warns yet and warning text is outside
  the logging contract (ADR-0021), so no test can observe it.

## Consequences

- For libmodsecurity v3 and Coraza: clear the pending marker when a phase ends.
- For all three engines: warn at load time about a `skipAfter` with no `SecMarker` of
  that label after it.
- For rule authors: a `SecMarker` for a `skipAfter` should be placed in the same phase;
  the spec no longer depends on it. The load-time warning points at the ones that are
  missing.

## Tests

- `tests/engine/processing/skipafter-later-phase.yaml`
- `tests/engine/processing/skipafter-missing-marker.yaml`

## References

- `spec/03-processing-model.md#flow-control`
- ModSecurity Reference Manual, `skipAfter`
