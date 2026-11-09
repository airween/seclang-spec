# ADR-0035: `noauditlog` affects relevance only; the audit record lists every logged match

- **Status:** proposed
- **Date:** 2026-11-09
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

`10-logging.md#audit-log-relevance` decides which transactions get an audit record: a
matched rule with `auditlog` and not `noauditlog`, OR a status matching
`SecAuditLogRelevantStatus`. It does not decide which matched rules the record lists in
part H. The engines differ for a rule with `log,noauditlog`, checked with the three
reference adapters (`RelevantOnly`, Native format, a `log,noauditlog` rule and a deny that
makes the transaction relevant):

| Matched rule | v2.9.15 | v3.0.17 | Coraza v3.8.1 |
|---|---|---|---|
| `log,noauditlog` | listed | not listed | not listed |
| `nolog,auditlog` | listed | listed | listed |
| `nolog`, `nolog,noauditlog` | not listed | not listed | not listed |

- ModSecurity v2 (`apache2/re.c` `msre_perform_disruptive_actions` and `msc_alert`) adds
  the message of every rule that logs, or that carries `auditlog` under `nolog`, to
  `msr->alerts`, which `apache2/msc_logging.c` writes as part H `Message:` lines;
  `noauditlog` only stops the rule from making the transaction relevant.
- libmodsecurity v3 keeps one flag for both logs: `log` and `auditlog` set
  `RuleMessage::m_saveMessage`, `nolog` and `noauditlog` clear it (`src/actions/log.cc`,
  `audit_log.cc`, `no_log.cc`, `no_audit_log.cc`), and part H writes only saved messages
  (`src/transaction.cc` `toOldAuditLogFormat`). The last of the four actions wins.
- Coraza lists a rule in part H only when its audit flag is set
  (`internal/corazawaf/transaction.go` `AuditLog`), which `noauditlog` clears.

With v3's and Coraza's reading, an operator who wants records only for relevant statuses
(`SecDefaultAction "phase:2,log,noauditlog,pass"` with `SecAuditLogRelevantStatus`) gets a
record for a blocked request that does not say which rules matched.

## Decision

`noauditlog` only stops a rule from making the transaction relevant. Part H of a written
record MUST list every matched rule that carries `log` or `auditlog`, explicitly or through
`SecDefaultAction`, whether or not it carries `noauditlog`. A rule with `nolog` and no
explicit `auditlog` is not listed. Relevance is unchanged
(`10-logging.md#audit-log-relevance`).

Both common setups then work:

- CRS defaults (`log,auditlog`): every detection makes a record listing its rules.
- Status decides (`SecDefaultAction` with `log,noauditlog,pass` and a
  `SecAuditLogRelevantStatus`): only a relevant status makes a record, and the record still
  lists every rule that matched.

## Options considered

- v3's single flag, last action wins: `noauditlog` hides the cause of a recorded block, and
  no configuration gives "status decides, the record shows what matched"; rejected.
- Leave part H's content unspecified: the record of a blocked request may or may not name
  the rule that blocked it; rejected.
- v2's reading (chosen): one action decides relevance, the other what is listed.

## Consequences

- For ModSecurity v2: none.
- For libmodsecurity v3: keep the error-log and audit-record decisions apart: `noauditlog`
  must not clear the message `log` saved.
- For Coraza: list rules with the log flag in part H even when the audit flag is cleared;
  relevance remains the separate OR of `10-logging.md#audit-log-relevance` (the known gap
  recorded in `compat/known-gaps.md`).
- For rule authors: `log,noauditlog` is the way to keep a rule from creating records on its
  own while keeping it visible in every record that is written.

## Tests

- `tests/engine/logging/audit-noauditlog-listed.yaml`
- `tests/engine/logging/audit-record-listing.yaml`

## References

- ADR-0021
- `spec/10-logging.md#audit-log-relevance`, `spec/10-logging.md#audit-log-parts`
- Report by @M4tteoP, 2026-11-09; Coraza PR 1824 (relevance as OR)
