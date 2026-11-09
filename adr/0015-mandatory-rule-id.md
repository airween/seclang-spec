# ADR-0015: Every rule carries an id

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

- ModSecurity v2 (`apache2/re.c`, "No action id present within the rule") and
  libmodsecurity v3 (`src/parser/driver.cc`, "Rules must have an ID") reject a `SecRule`
  or `SecAction` without an `id`, except chain members.
- Coraza 3.8.1 makes the check conditional on the build tag
  `coraza.rule.mandatory_rule_id_check` (`internal/corazawaf/rule_mandatory_idcheck*.go`),
  default off: a rule without an id loads and gets id 0.
- All three reject duplicate ids.

Rule ids are how every exclusion mechanism (`SecRuleRemoveById`, `ctl:ruleRemoveById`,
`SecRuleUpdateTargetById`, `skipAfter`) and every log line refer to a rule. A rule
without one cannot be excluded, updated or correlated.

## Decision

Every `SecRule` and `SecAction` that is not a chain member MUST carry an `id`; ids MUST
be unique within a loaded configuration. A missing or duplicate id MUST be a
configuration error. Chain members MUST NOT carry an id. Normative text:
`spec/02-grammar.md#secrule-structure`.

## Options considered

- Optional ids (Coraza default): convenient for one-off test rules, but silently
  produces unexcludable rules; rejected.
- Mandatory ids (chosen): ModSecurity behaviour since 2.7 and what CRS assumes.

## Consequences

- For Coraza: make the id check unconditional, or make the build tag opt *out* and note
  the non-conformance.
- For rule authors: none; CRS and every published ruleset already comply.

## Tests

- `tests/engine/grammar/secrule-requires-id.yaml`
- `tests/engine/grammar/duplicate-rule-id.yaml`

## References

- `spec/02-grammar.md#secrule-structure`
