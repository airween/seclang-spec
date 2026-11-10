# ADR-0030: A negated operator applies per value

- **Status:** accepted
- **Date:** 2026-10-09
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

`spec/02-grammar.md#operator` said that a rule with a negated operator (`!@streq abc`,
`!abc`) matches when the operator is false for *every* selected value. The three engines
apply the negation to each value and let the rule match as soon as one value matches:

- ModSecurity v2 (`apache2/re.c`, `execute_operator`): per target value, `rc == 1` with
  `op_negated` is "no match" and `rc == 0` with `op_negated` is a match; the rule loop
  stops at the first matching value unless `multiMatch`.
- libmodsecurity v3.0.16 (`src/operators/operator.cc`, `Operator::evaluateInternal`
  returns `!res` under `m_negation`; `src/rule_with_operator.cc` matches on the first
  value whose `executeOperatorAt` is true).
- Coraza v3.8.1 (`internal/corazawaf/rule.go`, `if r.operator.Negation { match = !match }`
  per value).

The differential run of the Lean model against Coraza (`adapters/coraza/cmd/differential`)
found the gap: with `ARGS_GET:a` holding `abc` and `zzz`, `!@streq abc` matches on every
engine and did not in the model, which had implemented the text. No Core profile had a
negated operator over more than one value.

## Decision

A leading `!` negates the operator's result for each selected value; the rule matches
when the operator is false for at least one selected value. A rule that selects no value
never matches (`06-operators.md#unconditionalmatch`). Normative text:
`spec/02-grammar.md#operator`.

## Options considered

- Keep "false for every value": no engine does it, and it would turn `!@streq` on a
  multi-valued collection into an all-quantifier no rule author expects; rejected.
- Per-value negation (chosen): what every engine does and what the reference manual
  describes.

## Consequences

- For the engines: none.
- For rule authors: `ARGS "!@rx ^[a-z]+$"` fires when any argument fails the pattern,
  the usual intent of an allow-list rule.
- For this repository: the Lean model negates per value; `operator-forms.yaml` gains a
  two-valued stage.

## Amendment (2026-11-10): `multiMatch`

The decision above names values; under `multiMatch` (`08-actions.md#multimatch`) one value
is evaluated several times, before any transformation and after each one. All three
engines negate each evaluation, so a negated rule matches when the operator is false for at
least one evaluation of at least one value:

- ModSecurity v2 (`apache2/re.c`, `msre_rule_process_normal`): calls `execute_operator`,
  which applies `op_negated`, at the raw value and after each transformation that changes it.
- libmodsecurity v3 (`src/rule_with_operator.cc`, `RuleWithOperator::evaluate`, read at
  v3.0.11): calls `executeOperatorAt` once per transformed value, and
  `Operator::evaluateInternal` negates each result; the v3.0.17 adapter passes the stage
  below.
- Coraza v3.8.1 (`internal/corazawaf/rule.go`, `executeOperator`): negates per entry of
  `executeTransformationsMultimatch`, whose first entry is the raw value.

The Lean model had negated once per value, after all of its evaluations (match only when
every evaluation failed); no profile combined `!` with `multiMatch`. The model now negates
per evaluation, `MATCHED_VAR` is the evaluation that matched, and
`tests/engine/actions/capture-multimatch.yaml` gains a negated stage. This amendment
clarifies the scope of the decision and changes nothing for the engines.

## Tests

- `tests/engine/grammar/operator-forms.yaml` (two values, one failing the operator)
- `tests/engine/actions/capture-multimatch.yaml` (negated operator under `multiMatch`)

## References

- `spec/02-grammar.md#operator`, `spec/06-operators.md#unconditionalmatch`
