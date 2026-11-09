# ADR-0028: `skipAfter` resolves to a `SecMarker`, never to a rule id

- **Status:** accepted
- **Date:** 2026-10-09
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

`skipAfter:LABEL` skips the rules that follow until `LABEL` is reached. The ModSecurity
reference manual describes `LABEL` as a `SecMarker`, and the legacy syntax also allowed a
rule id. What the engines resolve the label against:

- ModSecurity v2 (`apache2/apache2_config.c`, the `tmp_rule_placeholders` table): when a
  rule carrying `skipAfter:ID` has been seen and a rule with `id:ID` is later defined, the
  loader inserts a shallow copy of that rule marked `RULE_PH_SKIPAFTER` into the rule's own
  phase. The per-phase loop (`apache2/re.c`, `msre_ruleset_process_phase`, `SKIP_RULES`)
  ends the skip only at a placeholder rule whose id equals the label, so both a
  `SecMarker` (a `RULE_PH_MARKER` placeholder in every phase) and a rule id work; a target
  rule in another phase never ends the skip.
- libmodsecurity v3.0.16 (`src/rules_set.cc`, `RuleMarker::evaluate` in
  `headers/modsecurity/rule_marker.h`): the pending label is compared with marker names
  only. A rule whose id equals the label is skipped like any other rule.
- Coraza v3.8.1 (`internal/corazawaf/rulegroup.go`, `r.SecMark_ == tx.SkipAfter`): markers
  only, as v3.

No profile in this repository and no OWASP CRS rule uses a rule id as a `skipAfter` label.
Under v3 and Coraza a configuration that does so skips the rest of the phase (and, per
ADR-0016, the rest of the transaction), which is the opposite of the author's intent: the
rules after the target are silently disabled.

## Decision

In Core, the `LABEL` of `skipAfter:LABEL` names a `SecMarker`. A rule whose id equals
`LABEL` MUST NOT end the skip; when no `SecMarker LABEL` follows in the current phase the
skip ends with the phase (ADR-0016). Configurations that need to resume after a specific
rule MUST place a `SecMarker` after it. The rule-id form is Engine-specific (ModSecurity
v2). Normative text: `spec/03-processing-model.md#flow-control`,
`spec/08-actions.md#skipafter`.

## Options considered

- Rule id as a Core label (v2 behaviour): two engines would need a placeholder mechanism,
  and the manual never documented the form for `SecMarker`-era configurations; rejected.
- Markers only (chosen): what v3 and Coraza do, what every published ruleset does, and one
  `SecMarker` line gives any configuration the same effect on every engine.
- Unspecified: leaves a rule author with no portable reading of a label that happens to
  equal a rule id; rejected.

## Consequences

- For ModSecurity v2: none; the placeholder stays as an engine extension.
- For libmodsecurity v3 and Coraza: none.
- For rule authors: never reuse a rule id as a `skipAfter` label; add a `SecMarker`.
- For this repository: the Lean model (`formal/SecLang/Semantics.lean`) stops matching
  chain ids against the pending label; `compat/known-gaps.md` predicts the v2 behaviour
  for the new test.

## Tests

- `tests/engine/processing/skipafter-rule-id.yaml` (a label equal to a rule id does not
  end the skip)
- `tests/engine/actions/skipafter.yaml`, `tests/engine/processing/skip-and-skipafter.yaml`
  (`SecMarker` labels)

## References

- `spec/03-processing-model.md#flow-control`, ADR-0016
- ModSecurity reference manual, `skipAfter` and `SecMarker`
