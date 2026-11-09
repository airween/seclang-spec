# ADR-0034: `ctl:ruleEngine=Off` is final for the transaction

- **Status:** proposed
- **Date:** 2026-11-09
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

`03-processing-model.md#ctl-timing` leaves open whether the rest of the current phase is
evaluated after `ctl:ruleEngine=Off`, and asks rule authors to put the disabling rule last
in its phase. The engines differ, checked with the three reference adapters:

- ModSecurity v2.9.15 checks the mode before every rule (`apache2/re.c`
  `msre_ruleset_process_phase_`, `is_enabled == MODSEC_DISABLED` skips the rule). Once `Off`
  is set no later rule runs, including a later `ctl:ruleEngine`, so `Off` holds for the
  rest of the transaction.
- libmodsecurity v3.0.17 (`src/actions/ctl/rule_engine.cc` sets the transaction's mode;
  `src/transaction.cc` reads it only when a phase starts, "Rule engine disabled,
  returning...") and Coraza v3.8.1 (`internal/corazawaf/transaction.go`,
  `IsRuleEngineOff` at the start of each `Process*` call) keep evaluating the phase. A later
  rule of the same phase with `ctl:ruleEngine=DetectionOnly` or `=On` overwrites `Off`, and
  the next phases run again.

So an exclusion that turns the engine off for a path is undone by any later rule of its
phase that sets the mode, for example a rule that switches to `DetectionOnly` for a set of
clients. The current test puts `Off` last and cannot show the difference.

## Decision

After `ctl:ruleEngine=Off` the engine MUST NOT evaluate any further rule of the
transaction, in the current phase or a later one. No later action can change the mode
back, since none runs. `ctl:ruleEngine=On` and `=DetectionOnly` keep their current meaning:
they apply at once to the interruption decision of the current phase and to every later
phase.

The advice that a disabling rule SHOULD be the last rule of its phase is withdrawn.

## Options considered

- Last write wins, as v3 and Coraza do: a ruleset cannot rely on an exclusion, because any
  later mode change silently undoes it; rejected.
- Leave it unspecified: the outcome of a common exclusion pattern would depend on the
  engine; rejected.
- `Off` is final (chosen): matches v2 and the plain reading of "the engine is off".

## Consequences

- For ModSecurity v2: none.
- For libmodsecurity v3: stop evaluating rules once `ctl:ruleEngine=Off` has run, not only
  at the next phase.
- For Coraza: the same, in the phase loop.
- For rule authors: rules after an `Off` in the same phase no longer run anywhere; one that
  must run (logging, a `setvar` for a later decision) goes before the `Off`.

## Tests

- `tests/engine/processing/ctl-ruleengine-off-final.yaml`

## References

- ADR-0006
- `spec/03-processing-model.md#ctl-timing`, `spec/08-actions.md#ctlruleengine`
- Report by @M4tteoP, 2026-11-09
