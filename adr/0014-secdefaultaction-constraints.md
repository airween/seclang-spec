# ADR-0014: `SecDefaultAction` constraints

- **Status:** proposed
- **Date:** 2026-10-06
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

Checks each engine applies to a `SecDefaultAction` action list (all verified against
source on 2026-10-06; the v3 metadata and `tag` rows corrected on 2026-11-09 after the
libmodsecurity adapter loaded them):

| Check | ModSecurity v2 (`cmd_default_action`) | libmodsecurity v3 (`seclang-parser.yy`) | Coraza 3.8.1 (`rule_parser.go` `ParseDefaultActions`) |
|---|---|---|---|
| missing disruptive action | error | error | error |
| missing `phase` | error | **defaults to phase 1** | error |
| metadata actions (`id`, `rev`, `msg`, `severity`, `ver`, `accuracy`, `maturity`, `logdata`) | error | error for the configuration-kind `id`, `rev`, `ver`, `accuracy`, `maturity`; **accepts** the run-time `msg`, `severity`, `logdata` | error |
| `tag` | **not checked** (`ENH` comment) | **accepted** (run-time action) | error |
| `chain`, `skip`, `skipAfter` | error | error | error |
| `t:none` / transformations | warning | error on `t:none` | error on any `t:` |
| second `SecDefaultAction` for the same phase | **replaces** the first | error | error |
| when the check runs | at the directive | at the directive | **at the next rule parsed** |

Coraza also installs a built-in `phase:2,log,auditlog,pass` when none is configured.
ModSecurity v2 keeps a single current default action set whose phase a phase-less rule
inherits; the other two apply default actions by the rule's own phase (see ADR-0017).

## Decision

A `SecDefaultAction` MUST contain a `phase` and exactly one disruptive action, and MUST
NOT contain `chain`, `skip`, `skipAfter`, any transformation (including `t:none`) or the
metadata actions `id`, `rev`, `msg`, `tag`, `severity`, `ver`, `accuracy`, `maturity`,
`logdata`. At most one `SecDefaultAction` per phase MAY appear in one configuration
context; a second one for the same phase MUST be a configuration error. Violations MUST
be reported when the directive is parsed, whether or not a rule follows it. Normative
text: `spec/03-processing-model.md#default-actions`.

## Options considered

- v2 replacement semantics for a repeated phase: one engine against two, and silently
  changing the default for later rules is a frequent misconfiguration; rejected.
- Error on a repeated phase (chosen): v3 and Coraza behaviour; CRS complies (one per
  phase in `crs-setup.conf`).
- Allow `tag` as v2 does: a tag inherited by every rule defeats `ctl:ruleRemoveByTag`;
  rejected.

## Consequences

- For ModSecurity v2: reject `tag` and transformations (today it warns on the latter);
  reject a repeated phase (today it replaces). `default-action-redefined.yaml`,
  `default-action-tag.yaml` and `default-action-transformation.yaml` fail on v2.
- For libmodsecurity v3: require `phase` instead of defaulting to 1; reject `tag`, `msg`,
  `severity`, `logdata` and every transformation, not only `t:none`.
  `default-action-no-phase.yaml`, `default-action-tag.yaml`, `default-action-msg.yaml`
  and `default-action-transformation.yaml` fail on v3.
- For Coraza: validate at the directive, not at the next rule. `default-action-no-rule.yaml`
  fails on Coraza; the other negative tests pass only because a rule follows the directive.
- For rule authors: `SecDefaultAction "phase:N,log,auditlog,pass"` as CRS ships it is
  valid everywhere.
- Where it lives: with the ruleset whose rules depend on it, not in the engines'
  recommended configuration. CRS rules use `block` and leave logging to the default, so
  `crs-setup.conf.example` sets one per phase; `modsecurity.conf-recommended` (v2.9.15,
  v3.0.17) and `coraza.conf-recommended` (v3.8.1) set none, and their own rules state
  their actions in full. Since a second `SecDefaultAction` for a phase is an error, an
  engine's recommended configuration that added one would stop CRS from loading after it.
  The commented redirect example in `crs-setup.conf.example` carried a `tag`; CRS
  pull request 4959 removes it.

## Tests

- `tests/engine/processing/default-action-no-phase.yaml`
- `tests/engine/processing/default-action-no-disruptive.yaml`
- `tests/engine/processing/default-action-redefined.yaml`
- `tests/engine/processing/default-action-tag.yaml`
- `tests/engine/processing/default-action-msg.yaml`
- `tests/engine/processing/default-action-transformation.yaml`
- `tests/engine/processing/default-action-no-rule.yaml`

## References

- `spec/03-processing-model.md#default-actions`, `spec/04-directives.md#secdefaultaction`
- ADR-0017 (default phase)
