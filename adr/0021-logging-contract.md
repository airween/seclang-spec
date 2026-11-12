# ADR-0021: The portable logging contract is rule ids, messages and logdata

- **Status:** accepted
- **Date:** 2026-10-07
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

The engines agree on almost nothing in their log output beyond structure:

- Error log prefixes: `ModSecurity: Warning.` / `ModSecurity: Access denied with code N`
  (v2 `apache2/mod_security2.c`, v3 `src/rule_message.cc`) versus `Coraza: Warning.` /
  `Coraza: Access denied (phase N).` (`internal/corazarules/rule_match.go`). The bracketed
  fields `[id "…"]` and `[msg "…"]` appear in all three.
- Audit log JSON: v2, v3 and Coraza each have their own object layout; Coraza adds
  `jsonlegacy` and `ocsf`.
- Audit log parts: Coraza does not fill `D`, `E`, `G`; stopwatch and producer lines
  differ.
- Debug log: free text in ModSecurity, a structured logger in Coraza.
- `logdata`: all three write it as `[data "TEXT"]` with macros expanded on the logged
  match's line (v2 `apache2/re.c` `msre_format_metadata`, v3 `src/rule_message.cc`, Coraza
  `internal/corazarules/rule_match.go`), checked 2026-11-09 through the three reference
  adapters with `tests/engine/logging/logdata.yaml`. They differ in truncation (v2 512
  bytes, v3 200), escaping (v3 hex-escapes non-printable bytes, Coraza uses Go's `%q`) and
  in whether `[data]` appears without `logdata` (Coraza always writes it).

The design document (section 4.4) already excludes log layout from the test tiers:
"Logging tests assert only on rule IDs and `msg` presence."

## Decision

Normative logging behaviour is limited to: one error-log line per logged match carrying
`[id "N"]` and, when present, `[msg "TEXT"]` and the expanded `logdata` as
`[data "TEXT"]`, suppressed by `nolog`; audit-log relevance
rules; the set of audit parts with the minimum content of `A`, `B`, `F`, `H`, `Z`; and the
Native format's part-marker structure. The JSON audit format is Extended with an
unspecified shape; the debug log is Extended with unspecified wording. Engine-tier
profiles use `log_contains`/`no_log_contains` only with `msg` text or a `[data "TEXT"]`
field whose text is short, printable and free of quotes and backslashes; truncation and
escaping of longer or other text stay engine-specific.

## Options considered

- Specify ModSecurity's layout as Core: would make Coraza non-conforming for cosmetic
  reasons and freeze a format that log collectors already parse per engine; rejected.
- Specify nothing about logs: rules such as CRS's anomaly reporting rely on `msg` reaching
  the log, and adapters need a definition of `log_contains`; rejected.
- Leave `logdata` outside the contract: CRS puts the matched value in `logdata` on almost
  every detection rule and all three engines write it the same way for ordinary text;
  rejected once the adapters confirmed it.
- Minimum contract (chosen).

## Consequences

- For engines: none today; all three satisfy the contract.
- For adapters: implement `log_contains` over the error log or the engine's matched-rule
  messages.
- For log consumers: continue to parse per engine; a shared JSON schema is future work.
  `[data "…"]` carries `logdata` in every engine, but its length and escaping are not
  portable.

## Tests

- `tests/engine/logging/error-log-fields.yaml`
- `tests/engine/logging/audit-relevance-load.yaml`
- `tests/engine/logging/logdata.yaml`

## References

- ADR-0041 decides what a rule that matches several targets logs.
- `spec/10-logging.md`, `spec/08-actions.md#logdata`, `tests/README.md`
