# ADR-0041: Every matched target of a rule is logged with its own `logdata`

- **Status:** proposed
- **Date:** 2026-11-12
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

ADR-0021 requires "one error-log line per logged match", and `10-logging.md#error-log`
reads it per rule. Neither says what is logged when one rule matches several targets.
All three engines run the non-disruptive actions of a rule once per matching target, so a
`setvar:tx.score=+3` rule that matches two arguments adds 6. OWASP CRS anomaly scoring
relies on this. What reaches the logs differs. Checked on 2026-11-12 with
`SecRule ARGS_NAMES|ARGS "@rx '" "…,pass,log,auditlog,logdata:'in %{MATCHED_VAR_NAME}',setvar:tx.score=+3"`
and `GET /?username=ZAP%27&%27`, which matches `ARGS_NAMES:'` and `ARGS:username`:

| | Error log | Audit record |
|---|---|---|
| ModSecurity v2 | one line per target, each with its own `[data]` | one part H message per target |
| libmodsecurity v3 | one line, with the `[data]` of the last target only | one message, last target only |
| Coraza | one line: `[data]` of the first target, `[msg_match_N "…"] [data_match_N "…"]` for the others | part H only: one entry per rule (the error-log line); with part K: one entry per target |

- ModSecurity v2 (`apache2/re.c`, `execute_operator`): every match runs
  `msre_perform_disruptive_actions`, which writes the alert with `msc_alert`.
- libmodsecurity v3 (`src/rule_with_operator.cc`, `RuleWithOperator::evaluate`): one
  `RuleMessage` per rule. `m_match` is overwritten for each target, `logdata` is expanded
  once after the last one, and `RuleWithActions::performLogging` stores the message once.
- Coraza (`internal/corazawaf/rule.go`, `doEvaluate`): `msg` and `logdata` are expanded for
  each match of a rule that is not a chain starter. `MatchedRule.ErrorLog`
  (`internal/corazarules/rule_match.go`) writes them as `msg_match_N`/`data_match_N`.
  `Transaction.AuditLog` (`internal/corazawaf/transaction.go`) writes one message per
  match for part K, and the error-log line for part H.

So with libmodsecurity v3 the logs cannot explain the score: the example writes one 3-point
alert for a rule that added 6, and the first target is not named anywhere.

For a denying rule, ModSecurity v2 stops at the first matching target
(`msre_rule_process_normal`, `rule_was_intercepted`), so its actions run once and
`TX:score` is 3. libmodsecurity v3 and Coraza evaluate every target and reach 6.

These results come from the three engines driven directly: ModSecurity v2.9.15 under
Apache 2.4, libmodsecurity `v3/master` through its C API, and Coraza v3.7.0. The test
below runs them through the reference adapters.

## Decision

1. When a rule that is not part of a chain matches several targets and its non-disruptive
   actions run for each of them, every one of those matches MUST be logged. The rule's
   `logdata`, expanded for that match (`MATCHED_VAR` and `MATCHED_VAR_NAME` of that match),
   MUST appear in the error log unless the rule carries `nolog`. It MUST also appear in
   part H of a written audit record when part H lists the rule (ADR-0035).
2. Whether the matches share one line or get one line each, and which field carries the
   `logdata` of the second and later matches, is engine-specific.
3. A target whose match did not run the rule's actions need not be logged. An engine that
   stops evaluating a rule's targets once its disruptive action intercepts conforms.
   Whether an engine must evaluate the remaining targets of a denying rule is not decided
   here.
4. Chains and `multiMatch` are not decided here.

## Options considered

- One line per target, as ModSecurity v2 does: makes Coraza non-conforming over the
  layout of a log line, which ADR-0021 leaves to each engine; rejected.
- One audit message per target: Coraza writes them for part K only, and part K is not
  part of the portable record; rejected.
- Leave it unspecified: a consumer of the logs cannot tell which targets added to a
  score, or that a rule fired more than once; rejected.
- Require the content, not the layout (chosen): every match that ran the rule's actions is
  visible, in whichever form the engine writes it.

## Consequences

- For ModSecurity v2: none.
- For libmodsecurity v3: log every matched target with its own expanded `logdata`, not
  only the last one (known gap in `compat/known-gaps.md`).
- For Coraza: none.
- For rule authors: a `logdata` with `%{MATCHED_VAR_NAME}` or `%{MATCHED_VAR}` names every
  target that added to a score.
- For log consumers: count the expanded `logdata` values of a rule, not its lines, to
  reconstruct how often it ran.
- For tests: `log_contains` and `audit_log_contains` may assert a rule's expanded
  `logdata` text without the `[data "…"]` wrapper, because the second and later matches
  are not written as `[data]` in every engine (`tests/README.md`).

## Tests

- `tests/engine/logging/logdata-every-match.yaml`

## References

- ADR-0021, ADR-0035
- `spec/10-logging.md#error-log`, `spec/10-logging.md#audit-log-parts`
- libmodsecurity issues 3204, 2512 and 3755 (owasp-modsecurity/ModSecurity)
