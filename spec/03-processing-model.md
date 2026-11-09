# 03. Processing model

This file defines how an engine evaluates a loaded configuration against one HTTP
transaction: when rules run, how they combine, what a match does, and how a
configuration may alter rules defined earlier.

### Phases

**Status:** Core

**Syntax.** `phase:N` or `phase:NAME` in an action list, where `N` is 1 to 5 and the
names `request`, `response` and `logging` denote phases 2, 4 and 5.

**Semantics.** A transaction passes through five phases in order:

| Phase | Name | Runs after | Data available |
|---|---|---|---|
| 1 | request headers | request line and headers are read | `REQUEST_*`, `ARGS_GET`, `REQUEST_HEADERS`, `REQUEST_COOKIES` |
| 2 | request body (`request`) | the request body is read, if `SecRequestBodyAccess` is On | everything in phase 1 plus `ARGS_POST`, `ARGS`, `REQUEST_BODY`, `FILES*`, `XML`, `JSON` |
| 3 | response headers | the backend response status and headers are known | plus `RESPONSE_STATUS`, `RESPONSE_HEADERS` |
| 4 | response body (`response`) | the response body is read, if `SecResponseBodyAccess` is On and the MIME type is inspected | plus `RESPONSE_BODY` |
| 5 | logging (`logging`) | the response has been sent | everything; disruptive actions have no effect |

Within a phase, rules run in the order they appear in the configuration, after all
`Include`s are expanded. A rule without a `phase` action runs in phase 2; the phase is
**not** inherited from `SecDefaultAction` (ADR-0017). A rule's phase is fixed at load
time; variables not yet available in that phase are empty. Phase 5 rules MUST run even
when an earlier phase interrupted the transaction. Phase 4 rules run whether or not the
response body is inspected; when it is not (`SecResponseBodyAccess` Off, or a type not
listed by `SecResponseBodyMimeType`) `RESPONSE_BODY` is empty.

**Divergence notes.** libmodsecurity v3 does not evaluate phase 4 at all when the response
body is not inspected (`src/transaction.cc`, `processResponseBody` returns before
`evaluate(ResponseBodyPhase)`); ModSecurity v2 (`apache2/apache2_io.c`, `output_filter`,
"Process phase RESPONSE_BODY ... only if it hasn't been processed already") and Coraza
(`internal/corazawaf/transaction.go`, `ProcessResponseBody`) run it, so
`phase4-without-inspection.yaml` fails on v3 (`compat/known-gaps.md`). The default phase differs: ModSecurity v2 (`apache2/re.c`,
`actionset->phase = 2`) and Coraza (`internal/corazawaf/rule.go`, `Phase_: 2`) use
phase 2, libmodsecurity v3 (`headers/modsecurity/rule.h`, `m_phase(RequestHeadersPhase)`)
uses phase 1. ModSecurity v2 additionally lets a phase-less rule inherit the phase of
the most recent `SecDefaultAction`, whichever phase that names. See ADR-0017. Coraza can optionally evaluate a rule's variables in the earliest
phase where each is available (`coraza.rule.multiphase_evaluation` build tag). That mode
is permitted only where it is observationally equivalent to this section for every test
in this repository.

**Tests.** `tests/engine/processing/phases.yaml`,
`tests/engine/processing/default-phase.yaml`

### Chains

**Status:** Core

**Syntax.** The action `chain` on a rule makes the next `SecRule` or `SecAction` in the
configuration a member of the same chain. A member may itself carry `chain`.

**Semantics.** A chain is evaluated member by member; evaluation stops at the first
member that does not match, and the chain matches only if every member matched. The
first rule is the *chain starter*: it carries the chain's `id`, `phase`, metadata
(`msg`, `tag`, `severity`, `logdata`, `rev`, `ver`, `accuracy`, `maturity`),
disruptive action, `skip` and `skipAfter`, all of which apply when the whole chain
matches. Members MUST NOT carry `id`, `phase`, metadata or a disruptive action; a
configuration that does so MUST fail to load. Members MAY carry `t:`, `capture`,
`setvar`, `setenv`, `ctl`, `multiMatch` and `log`/`nolog`; these run when the member
matches, before the next member is evaluated. `SecDefaultAction` applies to the chain
starter only.

**Divergence notes.** All three engines reject a disruptive action on a chain member
(v2 `apache2/apache2_config.c` "Disruptive actions can only be specified by chain
starter rules", v3 `src/parser/driver.cc`, Coraza `internal/seclang/rule_parser.go`).

**Tests.** `tests/engine/processing/chain.yaml`

### Default actions

**Status:** Core

**Syntax.** `SecDefaultAction "ACTIONS"`

**Semantics.** A `SecDefaultAction` sets the action list that is merged into every
`SecRule` and `SecAction` of the same phase that appears after it in the configuration.
At most one `SecDefaultAction` per phase MAY appear in one configuration context; a
second one for the same phase MUST be a configuration error (ADR-0014). The phase of a
rule is never taken from `SecDefaultAction` (`#phases`). The rule's own actions take precedence
over inherited ones; cumulative actions (`tag:`, `setvar:`, `ctl:`) are appended.

The action list MUST contain a `phase` and exactly one disruptive action, and MUST NOT
contain `chain`, `skip`, `skipAfter`, any transformation (`t:`, including `t:none`), or
the metadata actions `id`, `rev`, `msg`, `tag`, `severity`, `ver`, `accuracy`,
`maturity` and `logdata`. Because no transformation can be inherited, a rule's `t:` list
is always its own. A violating
`SecDefaultAction` MUST be a configuration error (ADR-0014). When no `SecDefaultAction`
has been given for a phase, a rule of that phase that matches and names no disruptive
action behaves as `pass`.

**Divergence notes.** ModSecurity v2 (`apache2/apache2_config.c`, `cmd_default_action`)
rejects a missing disruptive action or phase and the actions `chain`, `skip`, `skipAfter`
and the metadata actions except `tag` (an `ENH` comment notes the gap), warns on
`severity`, `logdata` and transformations, and lets a later `SecDefaultAction` replace an
earlier one. libmodsecurity v3 (`src/parser/seclang-parser.yy`) rejects a missing
disruptive action, configuration-kind actions (`id`, `rev`, `ver`, `accuracy`,
`maturity`) and `t:none`, but accepts `tag`, `msg`, `severity`, `logdata` and other
transformations, defaults a missing phase to 1, and
rejects a second `SecDefaultAction` for the same phase. Coraza 3.8.1
(`internal/seclang/rule_parser.go`, `ParseDefaultActions`) rejects metadata actions,
transformations, a missing phase, a missing disruptive action and a second
`SecDefaultAction` for the same phase, but validates lazily, when the next rule is
parsed, so a violating directive followed by no rule loads. It applies a built-in
`phase:2,log,auditlog,pass` when none is configured. See ADR-0014.

**Tests.** `tests/engine/processing/default-action.yaml`,
`tests/engine/processing/default-action-no-phase.yaml`,
`tests/engine/processing/default-action-no-disruptive.yaml`,
`tests/engine/processing/default-action-redefined.yaml`,
`tests/engine/processing/default-action-tag.yaml`,
`tests/engine/processing/default-action-msg.yaml`,
`tests/engine/processing/default-action-transformation.yaml`,
`tests/engine/processing/default-action-no-rule.yaml`

### Disruptive actions

**Status:** Core

**Syntax.** Exactly one of `allow`, `block`, `deny`, `drop`, `pass`, `redirect:URL` in a
rule's effective action list.

**Semantics.** When a rule (or chain) matches and the engine is `On`:

- `deny` interrupts the transaction with the HTTP status given by `status:` (default
  403).
- `redirect:URL` interrupts with the status given by `status:` if it is 301, 302, 303 or
  307, otherwise 302 (`08-actions.md#redirect`), and the `Location` header set to `URL`
  (after macro expansion).
- `drop` interrupts by closing the connection without an HTTP response where the
  integration allows it; otherwise it behaves as `deny`. Adapters report the action as
  `drop` regardless of status.
- `allow` interrupts rule processing for the rest of the current phase (`allow:phase`),
  the rest of the request phases (`allow:request`) or all remaining phases except
  logging (`allow`), letting the transaction proceed.
- `pass` does not interrupt; processing continues with the next rule.
- `block` is a placeholder replaced at load time by the disruptive action inherited from
  `SecDefaultAction`; if none is inherited it behaves as `pass`.

Only the first interrupting rule of a phase takes effect: once a rule interrupts, the
remaining rules of that phase MUST NOT be evaluated, and phases 2 to 4 MUST NOT run; phase
5 MUST run. In `DetectionOnly` the rule matches and logs but nothing interrupts.
`status:` without a disruptive action that uses it has no effect.

**Divergence notes.** None known for the behaviours above.

**Tests.** `tests/engine/processing/disruptive-actions.yaml`

### Flow control

**Status:** Core

**Syntax.** `skip:N`, `skipAfter:LABEL` in an action list; `SecMarker LABEL` as a
directive.

**Semantics.** When a rule carrying `skip:N` matches, the next `N` rules *of the same
phase* in configuration order are not evaluated (a chain counts as one rule). When a rule
carrying `skipAfter:LABEL` matches, evaluation jumps to the first `SecMarker LABEL` that
follows it in configuration order, and resumes with the rule after it. A rule whose id
equals `LABEL` MUST NOT end the skip (ADR-0028). A `SecMarker` is a phase-less placeholder:
it never evaluates anything and exists in every phase. If the marker is not found before
the end of the current phase, the skip ends with the phase: rules of later phases MUST run
normally (ADR-0016). Because markers exist in every phase, that happens exactly when no
`SecMarker LABEL` follows the rule in configuration order; an engine SHOULD warn when it
loads such a rule, naming the rule and the label, and MUST still load the configuration.
The warning's wording and destination are engine-specific (`10-logging.md`).
`skipAfter` and `skip` MUST NOT appear on chain members.

**Divergence notes.** ModSecurity v2 (`apache2/re.c`, `skip_after` is local to the
per-phase rule loop) and the ModSecurity reference manual scope the skip to the current
phase. libmodsecurity v3 (`Transaction::m_marker`) and Coraza 3.8.1
(`Transaction.SkipAfter`) store the pending marker on the transaction and clear it only
when a marker of that name is evaluated. Because markers are phase-less and both engines
evaluate every marker in every phase, a marker placed among later-phase rules is still
reached in the current phase and the outcome matches this section (verified for Coraza
by `adapters/coraza`). The behaviours differ only when **no** marker of that name exists:
v3 and Coraza then skip every remaining rule of every later phase. See ADR-0016. ModSecurity
v2 also ends the skip at a rule whose id equals the label, through a `RULE_PH_SKIPAFTER`
placeholder inserted in the target rule's own phase (`apache2/apache2_config.c`);
libmodsecurity v3 (`src/rules_set.cc`, markers only) and Coraza
(`internal/corazawaf/rulegroup.go`, `SecMark_`) do not, and ADR-0028 keeps the id form out
of Core. Under `skip:N`, Coraza counts a `SecMarker` as a rule and does not
count a rule removed by `ctl`; v2 and v3 do the reverse. This section does not decide
either and no profile depends on it.

**Tests.** `tests/engine/processing/skip-and-skipafter.yaml`,
`tests/engine/processing/skipafter-later-phase.yaml`,
`tests/engine/processing/skipafter-missing-marker.yaml`,
`tests/engine/processing/skipafter-rule-id.yaml`

### Rule exceptions

**Status:** Core

**Syntax.**
`SecRuleRemoveById ID|RANGE [ID|RANGE ...]`,
`SecRuleRemoveByTag TAG`,
`SecRuleRemoveByMsg MSG` (Extended),
`SecRuleUpdateTargetById ID|RANGE "TARGETS"`,
`SecRuleUpdateTargetByTag TAG "TARGETS"`,
`SecRuleUpdateTargetByMsg MSG "TARGETS"` (Extended),
`SecRuleUpdateActionById ID|RANGE "ACTIONS"`.
A `RANGE` is `A-B` with `A <= B`, inclusive.

**Semantics.** Each directive applies to the rules already defined when it is
encountered; a rule defined later is unaffected. `Remove*` deletes matching rules.
`UpdateTarget*` edits the variable list: a target with a leading `!` is appended as an
exclusion (`!ARGS:foo`), one without is appended as an additional variable. `TARGETS` uses
the `|` syntax of `02-grammar.md#variable-list`. `UpdateActionById` merges `ACTIONS` into
the rule's action list with the same precedence as a rule's own actions over
`SecDefaultAction`: a disruptive action replaces the existing one. An id or range that
matches no rule is silently ignored. A range with `A > B` MUST be a configuration error.
`ByTag` selects a rule when one of its `tag` values equals `TAG`; `ByMsg` when its `msg`
equals `MSG`. Both are literals: whether a rule is also selected when the parameter matches
a tag or the message as an unanchored regular expression is **not specified** (ADR-0029);
portable configurations write the full tag or message. The `ctl:` forms (`ruleRemoveById`, `ruleRemoveByTag`,
`ruleRemoveTargetById`, `ruleRemoveTargetByTag`) apply the same edits for the current
transaction only.

**Divergence notes.** ModSecurity v2 does not validate the range order
(`cmd_rule_update_target_by_id` carries a `TODO` to that effect; `rule_id_in_range` never
checks it), so `rule-exceptions-bad-range.yaml` fails on v2; libmodsecurity v3
(`src/rules_exceptions.cc`, "Invalid range") and Coraza (`directives.go`, "invalid
range") reject it. Coraza rejects `SecRuleUpdateTargetById` with a single id that matches
no rule (`directives.go`, `rule "%d" not found`), where ModSecurity v2 and libmodsecurity
v3 (`rules_exceptions.cc`, exceptions are stored and applied lazily) ignore it, so
`rule-exceptions-unknown-id.yaml` fails on Coraza. Coraza accepts
`SecRuleUpdateTargetByMsg` and ignores it (ADR-0005). ModSecurity v2 matches the `ByTag`
and `ByMsg` parameters as unanchored regular expressions in every form (`apache2/re.c`,
`msre_ruleset_rule_matches_exception`; `apache2/re_actions.c` for `ctl:`), so
`rule-exceptions-tag-literal.yaml` fails on v2; libmodsecurity v3
(`src/rule_with_actions.cc`, `containsTag`, `containsMsg`) and Coraza
(`internal/corazawaf/rulegroup.go`, `internal/actions/ctl.go`, `utils.InSlice`) compare
exactly. See ADR-0029 and `compat/known-gaps.md`.

**Tests.** `tests/engine/processing/rule-exceptions.yaml`,
`tests/engine/processing/rule-exceptions-update-action.yaml`,
`tests/engine/processing/rule-exceptions-bad-range.yaml`,
`tests/engine/processing/rule-exceptions-unknown-id.yaml`,
`tests/engine/processing/rule-exceptions-tag-literal.yaml`,
`tests/engine/processing/phase4-without-inspection.yaml`

### ctl timing

**Status:** Core

**Syntax.** `ctl:OPTION=VALUE` in an action list; options are listed in
`08-actions.md` and their statuses fixed by ADR-0006.

**Semantics.** A `ctl` action runs when its rule matches, in that rule's phase, and its
effect lasts for the remainder of the transaction. Options that edit rules
(`ruleRemoveById`, `ruleRemoveByTag`, `ruleRemoveTargetById`, `ruleRemoveTargetByTag`)
take effect immediately: the next rule evaluated in the same phase already sees them.
`ctl:ruleEngine` changes the mode for every later phase and, at once, for the
interruption decision of the current phase: after `On` a later matching rule of the same
phase interrupts, after `DetectionOnly` or `Off` none does (all three engines read the
mode when they interrupt: ModSecurity v2 `apache2/re.c` `msre_perform_disruptive_actions`,
libmodsecurity v3 `src/rule_with_actions.cc` `executeAction`, Coraza
`internal/corazawaf/transaction.go` `Interrupt`). After `Off` the engine MUST NOT evaluate
any further rule of the transaction, in the current phase or a later one, so no later
`ctl:ruleEngine` can switch inspection back on (ADR-0034; v3 and Coraza still evaluate the
rest of the phase, `compat/known-gaps.md`). The other state options
(`auditEngine`, `auditLogParts`, `requestBodyAccess`, `requestBodyProcessor`,
`forceRequestBodyVariable`) apply to whatever the engine does after the rule matched. Options that
control request body handling (`requestBodyAccess`, `requestBodyProcessor`,
`forceRequestBodyVariable`) have an effect only when set in phase 1, before the body is
read.

**Divergence notes.** ModSecurity v2 re-checks the engine state before every rule
(`apache2/re.c`, `is_enabled == MODSEC_DISABLED` inside the rule loop), so
`ctl:ruleEngine=Off` also silences the rest of the current phase; libmodsecurity v3
(`src/transaction.cc`, "Rule engine disabled, returning" at phase entry) and Coraza
(`transaction.go`, `IsRuleEngineOff()` at phase entry) only check when a phase starts.
Rule-removal options are immediate in all three (v2 same loop, v3 `rules_set.cc`
`m_exceptions`, Coraza `rulegroup.go` `ruleRemoveByID`).

**Tests.** `tests/engine/processing/ctl-timing.yaml`,
`tests/engine/processing/ctl-ruleengine-off-final.yaml`,
`tests/engine/processing/ctl-core-options-load.yaml`
