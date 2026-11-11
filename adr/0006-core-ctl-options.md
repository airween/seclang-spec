# ADR-0006: Core `ctl:` options

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-11
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween, @franbuehler, @theseion
- **Category:** Divergence

## Context

The `ctl` action has 20 option names across the three engines and only 10 in all three
(`compat/matrix.md`). libmodsecurity v3 lacks `requestBodyLimit`, `responseBodyAccess`,
`responseBodyLimit`, `ruleRemoveByMsg`, `ruleRemoveTargetByMsg`, `debugLogLevel`,
`hashEngine` and `hashEnforcement`; Coraza lacks `parseXmlIntoArgs`; only Coraza has
`responseBodyProcessor`. OWASP CRS v4 uses `requestBodyProcessor`, `ruleRemoveByTag`,
`ruleRemoveById`, `forceRequestBodyVariable`, `auditEngine` and `ruleRemoveTargetByTag`;
the CRS documentation for user exclusions relies on `ruleRemoveTargetById` and
`ruleEngine`.

`ctl:auditLogParts` has two value forms: relative (`+E`, `-E`) and absolute (`ABCZ`).
ModSecurity v2 accepts both (`apache2/re_actions.c`), libmodsecurity v3 accepts only the
relative form (`seclang-scanner.ll`, `=[+|-]{AUDIT_PARTS}`), Coraza accepts both
(`types.ApplyAuditLogParts` falls back to `ParseAuditLogParts`; relative form since Coraza
ADR-0032). Coraza also has a 21st option, `forceResponseBodyVariable`, missed by the
Phase 1 survey and added to the matrix in Phase 3.

## Decision

| Status | Options |
|---|---|
| Core | `auditEngine`, `auditLogParts` (relative and absolute forms), `forceRequestBodyVariable`, `requestBodyAccess`, `requestBodyProcessor`, `ruleEngine`, `ruleRemoveById`, `ruleRemoveByTag`, `ruleRemoveTargetById`, `ruleRemoveTargetByTag` |
| Extended | `requestBodyLimit`, `responseBodyAccess`, `responseBodyLimit`, `ruleRemoveByMsg`, `ruleRemoveTargetByMsg`, `debugLogLevel`, `parseXmlIntoArgs` |
| Deprecated | `hashEngine`, `hashEnforcement` |
| Engine-specific | `responseBodyProcessor`, `forceResponseBodyVariable` (Coraza) |

Option names match case-insensitively (ADR-0002). The timing rules are in
`spec/03-processing-model.md#ctl-timing`; the full per-option specification lands with
the actions in Phase 3.

## Options considered

- Core = every option any engine has: forces hash-engine options on engines without a
  hash engine; rejected.
- Core = strict three-way intersection (chosen): it already covers everything CRS and
  its documented exclusion mechanisms use.
- `ctl:auditLogParts`, absolute form Extended (this ADR's first version): it was left out
  of Core only because libmodsecurity v3 rejects it. Both forms are Core instead (amended
  2026-11-11, before acceptance): v2 and Coraza already accept both, the absolute form is
  what `SecAuditLogParts` takes, and v3's gap is a scanner rule.

## Consequences

- For libmodsecurity v3: the eight missing options are Extended, so not required.
  `ctl:auditLogParts` MUST also accept the absolute form; the scanner rule
  (`seclang-scanner.ll`, `=[+|-]{AUDIT_PARTS}`) makes the sign optional.
  `ctl-auditlogparts-absolute.yaml` fails on v3.
- For Coraza: `parseXmlIntoArgs` is Extended, not required.
- For rule authors: `ctl:auditLogParts=+E` and `ctl:auditLogParts=ABCEZ` are both portable
  once v3 accepts the absolute form.

## Tests

- `tests/engine/processing/ctl-timing.yaml`
- `tests/engine/processing/ctl-core-options-load.yaml`
- `tests/engine/actions/ctl-auditlogparts-absolute.yaml`

## References

- `spec/03-processing-model.md#ctl-timing`, `spec/04-directives.md#secauditlogparts`
- Coraza ADR-0032 in `corazawaf/coraza/docs/adr`
