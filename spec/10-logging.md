# 10. Logging

Engines produce three kinds of log output: an **error log** line per rule match, an
**audit log** entry per relevant transaction, and a **debug log**. Their exact wording
and layout are where the three engines differ most, and no ruleset depends on them, so
this file specifies the minimum that rules and operators need to agree on (ADR-0021) and
leaves the rest to each engine's documentation. Conformance tests never assert on log
layout; they assert on which rules matched, for the error log that a rule's `msg` text
and `[data "…"]` field appear, and, for both logs, that a value a `sanitize*` action masks does not
(`tests/README.md`). A value marked by a `sanitize*` action
(`08-actions.md#sanitizearg`) never appears in clear in the error or audit log; the debug
log is not masked (ADR-0033).

### Error log

**Status:** Core

**Semantics.** For every rule that matches and does not carry `nolog`, the engine MUST
write one line to its error log (the host's error log, or the engine's own) containing
the fields `[id "N"]`, with the rule's id, and, when the rule has one, `[msg "TEXT"]`, with
the `msg` after macro expansion, and, when the rule has `logdata`, `[data "TEXT"]`, with
the `logdata` after macro expansion (`08-actions.md#logdata`). When a disruptive action
interrupts the transaction the line MUST say so. A rule carrying `nolog` MUST NOT produce
this line.

Everything else about the line is engine-specific: the prefix (`ModSecurity: Warning.`,
`ModSecurity: Access denied with code N`, `Coraza: Warning.`, `Coraza: Access denied
(phase N).`), the order of fields, the presence of `[data]` when the rule has no
`logdata`, and the presence of `[file]`, `[line]`, `[severity]`, `[ver]`, `[tag]`,
`[hostname]`, `[uri]`, `[unique_id]`. How a `"`, a `\` or a non-printable byte inside
`msg` or `logdata` is escaped, and how long `[data]` text may be before it is truncated,
are engine-specific; portable tests keep such text short, printable and free of quotes
and backslashes.

**Divergence notes.** ModSecurity v2 (`apache2/re.c`, `apache2/mod_security2.c`) and
libmodsecurity v3 (`src/rule_message.cc`) emit `ModSecurity: …`; Coraza
(`internal/corazarules/rule_match.go`) emits `Coraza: …` with the phase in the denial
message. All three write `[id "…"]` and `[msg "…"]`, and `[data "…"]` for `logdata`
(checked 2026-11-09 through the three reference adapters). They differ beyond that:
ModSecurity v2 truncates `[data]` at 512 bytes with an ellipsis (`apache2/re.c`,
`msre_format_metadata`), libmodsecurity v3 at 200 bytes, hex-escaping bytes that are not
printable (`src/rule_message.cc`, `toHexIfNeeded`), and Coraza writes `[data ""]` on every
line and escapes with Go's `%q` (`internal/corazarules/rule_match.go`).

**Tests.** `tests/engine/logging/error-log-fields.yaml`, `tests/engine/logging/logdata.yaml`

### Audit log relevance

**Status:** Core

**Semantics.** With `SecAuditEngine On` every transaction produces an audit entry. With
`RelevantOnly` an entry is produced when at least one matched rule carried `auditlog`
(explicitly or inherited from `SecDefaultAction`) and not `noauditlog`, or when the
response status matches `SecAuditLogRelevantStatus`. With `Off` none is produced.
`ctl:auditEngine` overrides the mode for one transaction. `nolog` implies `noauditlog`
unless `auditlog` is given explicitly (`08-actions.md#nolog`). The two relevance triggers
combine with OR. The entry is written after phase 5.

**Divergence notes.** ModSecurity v2 (`apache2/re.c`, `auditlog` defaults to on) and
libmodsecurity v3 (`src/audit_log/audit_log.cc`, saves unless every message carries
`noauditlog`) treat a match as relevant unless `noauditlog` is set; Coraza 3.8.1
(`transaction.go`) requires `auditlog` explicitly or via `SecDefaultAction`, and when
`SecAuditLogRelevantStatus` is configured it additionally requires the status to match
(AND, not OR; Coraza issue 1576). Relevance is not observable through the test schema,
because adapters force `SecAuditEngine On` for a profile that asserts on the audit log, so
this is recorded in `compat/known-gaps.md` only.

**Tests.** `tests/engine/logging/audit-relevance-load.yaml`

### Audit log parts

**Status:** Core

**Semantics.** `SecAuditLogParts` (`04-directives.md#secauditlogparts`) selects the parts
of an entry. The parts and what they MUST contain when requested and available:

| Part | Content |
|---|---|
| A | Header: timestamp, `UNIQUE_ID`, client address and port, server address and port |
| B | Request line and request headers as received |
| C | Request body (when buffered) |
| D | Reserved |
| E | Intermediary response body (when buffered) |
| F | Response status line and headers |
| G | Reserved |
| H | Trailer: one message line per matched rule (the error-log line or its equivalent), the engine's producer string and `SecComponentSignature` values, the rule engine mode, and the response action |
| I | Request body with file contents replaced by their metadata (multipart) |
| J | Information about uploaded files |
| K | The full text of every matched rule |
| Z | Terminator |

`A` and `Z` are mandatory. An engine MAY leave a requested part empty when it does not
implement it (Coraza: `D`, `E`, `G`), but MUST still emit the part markers for `A`, `B`,
`F`, `H` and `Z`, and part `H` (or `K`) MUST name the id of every matched rule.

**Divergence notes.** The wording inside every part is engine-specific; ModSecurity's
stopwatch and producer lines in `H` have no exact Coraza equivalent.

**Tests.** `tests/engine/logging/audit-relevance-load.yaml`

### Native format

**Status:** Core

**Semantics.** `SecAuditLogFormat Native`: each part is introduced by a line
`--BOUNDARY-X--`, where `X` is the part letter and `BOUNDARY` is an identifier unique to
the entry, followed by the part's content and a blank line; the entry ends with the `Z`
marker. In serial mode entries are appended to `SecAuditLog`; in concurrent mode each
entry is its own file under `SecAuditLogStorageDir` and `SecAuditLog` receives an index
line.

**Divergence notes.** None known for the structure (v2 `apache2/msc_logging.c`, v3
`Transaction::toOldAuditLogFormat` with `Writer::generateBoundary`, Coraza
`internal/auditlog/formats.go`).

**Tests.** `tests/engine/logging/audit-relevance-load.yaml`

### JSON format

**Status:** Extended

**Semantics.** `SecAuditLogFormat JSON` writes one JSON object per entry. Engines MUST
accept the value; the object's shape is **not specified** (ADR-0021).

**Divergence notes.** ModSecurity v2 (`AUDITLOGFORMAT_JSON`), libmodsecurity v3
(`JSONAuditLogFormat`) and Coraza (`json`; also `jsonlegacy`, which approximates the v2
shape, and `ocsf`) produce three different object layouts.

### Debug log

**Status:** Extended

**Semantics.** `SecDebugLog` and `SecDebugLogLevel` (`04-directives.md`) control a
diagnostic log whose wording is engine-specific and never asserted. Levels 1 to 3 SHOULD
correspond to error, warning and notice; higher levels add rule-evaluation detail.

**Divergence notes.** Coraza routes debug output through a structured logger (its
ADR-0009); ModSecurity writes free text.
