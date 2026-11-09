# ADR-0029: Tag and message rule exceptions select by exact string

- **Status:** accepted
- **Date:** 2026-10-09
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

`SecRuleRemoveByTag`, `SecRuleUpdateTargetByTag`, `ctl:ruleRemoveByTag` and
`ctl:ruleRemoveTargetByTag` select rules by a `tag` value; the `ByMsg` forms select by the
`msg`. How the parameter is compared with a rule's tags or message:

- ModSecurity v2 compiles the parameter as a regular expression and matches it unanchored,
  for the directives (`apache2/re.c`, `msre_ruleset_rule_matches_exception`,
  `msc_regexec` on each tag and on `msg`; `apache2/apache2_config.c`, `msc_pregcomp` in
  `cmd_rule_update_target_by_tag`) and for the `ctl:` forms (`apache2/re_actions.c`,
  `msc_pregcomp` of the `ruleRemoveTargetByTag` parameter). `SecRuleRemoveByTag attack`
  therefore also removes every rule tagged `attack-sqli`.
- libmodsecurity v3.0.16 compares exactly: `RuleWithActions::containsTag` and
  `containsMsg` (`src/rule_with_actions.cc`) test `==`, and both the directive forms
  (`src/rules_set.cc`, `m_remove_rule_by_tag`, `m_remove_rule_by_msg`;
  `src/rule_with_operator.cc`, `m_variable_update_target_by_tag`) and the `ctl:` forms
  (`m_ruleRemoveTargetByTag`) go through them.
- Coraza v3.8.1 compares exactly: `utils.InSlice(tag, r.Tags_)` in
  `internal/corazawaf/rulegroup.go` (`DeleteByTag`), `internal/seclang/directives.go`
  (`SecRuleUpdateTargetByTag`) and `internal/actions/ctl.go` (`ruleRemoveByTag`,
  `ruleRemoveTargetByTag`); `ruleRemoveTargetByMsg` tests `r.Msg.String() == a.value`.

Until now the specification said the parameter is a regular expression matched
unanchored, which is the ModSecurity v2 reading only. Every published exclusion the
maintainers know of (OWASP CRS documentation, the recommended configurations) writes a
full tag such as `attack-sqli` or `OWASP_CRS/ATTACK-SQLI`, on which the two readings agree
unless the tag is a substring of another tag or contains a regex metacharacter.

## Decision

The parameter of the `ByTag` forms is a literal `TAG`: a rule is selected when one of its
`tag` values equals `TAG`. The parameter of the `ByMsg` forms is a literal `MSG`: a rule is
selected when its `msg` equals `MSG`. Whether a rule is also selected when the parameter
matches a tag or the message as an unanchored regular expression is **not specified**;
portable configurations MUST write the full tag or message and MUST NOT rely on substring
or regular-expression matching. Normative text: `spec/03-processing-model.md#rule-exceptions`,
`spec/04-directives.md#secruleremovebytag`, `spec/04-directives.md#secruleupdatetargetbytag`,
`spec/08-actions.md#ctlruleremovebytag`, `spec/08-actions.md#ctlruleremovetargetbytag`.

## Options considered

- Regular expression as Core (v2, the previous text): two engines compare exactly and
  would have to compile every exclusion as a pattern; a tag such as `OWASP_CRS` would
  silently match every CRS rule on one engine and one rule on the others; rejected.
- Exact string as Core, regex unspecified (chosen): the intersection, what two engines do,
  and what every published exclusion already assumes.
- Exact string as Core, regex forbidden: would make ModSecurity v2 non-conforming on
  configurations it accepts; not needed, since the portable subset is the literal.

## Consequences

- For ModSecurity v2: none; the regex reading remains an engine extension.
- For libmodsecurity v3 and Coraza: none.
- For rule authors: write full tags; a tag that is a prefix of other tags (`OWASP_CRS` of
  `OWASP_CRS/ATTACK-SQLI`) selects only the rules carrying exactly that tag, on every engine.
- For this repository: the Lean model compares tags and messages exactly;
  `compat/known-gaps.md` predicts the v2 behaviour for the new test.

## Tests

- `tests/engine/processing/rule-exceptions-tag-literal.yaml` (a tag that is a prefix of
  another tag selects only its own rules, directive and `ctl:` forms)
- `tests/engine/processing/rule-exceptions.yaml`, `tests/engine/actions/ctl-options.yaml`,
  `tests/engine/directives/secruleupdatetargetbytag.yaml` (full tags)

## References

- `spec/03-processing-model.md#rule-exceptions`, ADR-0005 (`ByMsg` status)
- ModSecurity reference manual, `SecRuleRemoveByTag`, `SecRuleUpdateTargetByTag`, `ctl`
