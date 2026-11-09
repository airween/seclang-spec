# 08. Actions

Actions say what a rule does when it matches: metadata, logging, flow control, variable
changes, engine control (`ctl`) and exactly one disruptive action
(`02-grammar.md#action-list`, `03-processing-model.md`). The two indexes list every action
and every `ctl:` option known to any surveyed engine with its status (`00-conventions.md`,
ADR-0006). Only the `sanitize*` spellings are specified; v2's `sanitise*` spellings are not
aliases (ADR-0033).

## Index of actions

| Action | Status | v2 | v3 | Coraza | Purpose |
|---|---|---|---|---|---|
| [accuracy](#accuracy) | Extended | yes | yes | yes | Rule accuracy metadata 1–9 |
| [allow](#allow) | Core | yes | yes | yes | Stop processing and let the transaction through |
| [append](#append) | Deprecated | yes | - | - | Append content to the response |
| [auditlog](#auditlog) | Core | yes | yes | yes | Mark the transaction for audit logging |
| [block](#block) | Core | yes | yes | yes | Use the SecDefaultAction disruptive action |
| [capture](#capture) | Core | yes | yes | yes | Store regex groups in TX:0..9 |
| [chain](#chain) | Core | yes | yes | yes | Chain with the next rule |
| [ctl](#ctl) | Core | yes | yes | yes | Change engine configuration for this transaction |
| [deny](#deny) | Core | yes | yes | yes | Interrupt with an HTTP status |
| [deprecatevar](#deprecatevar) | Deprecated | yes | - | - | Decrement a variable over time |
| [drop](#drop) | Core | yes | yes | yes | Close the connection |
| [exec](#exec) | Extended | yes | yes | yes | Run an external script |
| [expirevar](#expirevar) | Extended | yes | yes | yes | Expire a persistent variable |
| [id](#id) | Core | yes | yes | yes | Rule identifier |
| [initcol](#initcol) | Extended | yes | yes | yes | Initialise a persistent collection |
| [log](#log) | Core | yes | yes | yes | Log the match to the error log |
| [logdata](#logdata) | Core | yes | yes | yes | Extra data for the log message |
| [marker](#marker) | Deprecated | yes | - | - | Internal: SecMarker placeholder |
| [maturity](#maturity) | Extended | yes | yes | yes | Rule maturity metadata 1–9 |
| [msg](#msg) | Core | yes | yes | yes | Log message |
| [multiMatch](#multimatch) | Core | yes | yes | yes | Evaluate the operator after each transformation |
| [noauditlog](#noauditlog) | Core | yes | yes | yes | Do not audit-log this transaction for this rule |
| [nolog](#nolog) | Core | yes | yes | yes | Do not log the match |
| [pass](#pass) | Core | yes | yes | yes | Continue with the next rule |
| [pause](#pause) | Deprecated | yes | - | - | Delay the response |
| [phase](#phase) | Core | yes | yes | yes | Processing phase |
| [prepend](#prepend) | Deprecated | yes | - | - | Prepend content to the response |
| [proxy](#proxy) | Deprecated | yes | - | - | Proxy the request elsewhere |
| [redirect](#redirect) | Core | yes | yes | yes | Interrupt with a redirect |
| [rev](#rev) | Extended | yes | yes | yes | Rule revision metadata |
| [sanitizeArg](#sanitizearg) | Extended | yes | - | - | Mask an argument in the logs |
| [sanitizeMatched](#sanitizematched) | Extended | yes | - | - | Mask the matched variable in the logs |
| [sanitizeMatchedBytes](#sanitizematchedbytes) | Extended | yes | - | - | Mask matched bytes in the logs |
| [sanitizeRequestHeader](#sanitizerequestheader) | Extended | yes | - | - | Mask a request header in the logs |
| [sanitizeResponseHeader](#sanitizeresponseheader) | Extended | yes | - | - | Mask a response header in the logs |
| [setenv](#setenv) | Extended | yes | yes | yes | Set a process environment variable |
| [setrsc](#setrsc) | Extended | yes | yes | - | Initialise the RESOURCE collection |
| [setsid](#setsid) | Extended | yes | yes | - | Initialise the SESSION collection |
| [setuid](#setuid) | Extended | yes | yes | - | Initialise the USER collection |
| [setvar](#setvar) | Core | yes | yes | yes | Set, change or delete a variable |
| [severity](#severity) | Core | yes | yes | yes | Rule severity 0–7 |
| [skip](#skip) | Extended | yes | yes | yes | Skip the next N rules |
| [skipAfter](#skipafter) | Core | yes | yes | yes | Skip to a SecMarker |
| [status](#status) | Core | yes | yes | yes | HTTP status for deny or redirect |
| [t](#t) | Core | yes | yes | yes | Add a transformation |
| [tag](#tag) | Core | yes | yes | yes | Rule tag |
| [ver](#ver) | Core | yes | yes | yes | Rule set version |
| [xmlns](#xmlns) | Extended | yes | yes | - | XML namespace for XPath |

## Index of ctl options

| ctl option | Status | v2 | v3 | Coraza | Purpose |
|---|---|---|---|---|---|
| [ctl:auditEngine](#ctlauditengine) | Core | yes | yes | yes | Audit logging for this transaction |
| [ctl:auditLogParts](#ctlauditlogparts) | Core | yes | yes | yes | Audit parts for this transaction |
| [ctl:debugLogLevel](#ctldebugloglevel) | Extended | yes | - | yes | Debug level for this transaction |
| [ctl:forceRequestBodyVariable](#ctlforcerequestbodyvariable) | Core | yes | yes | yes | Populate REQUEST_BODY for any content type |
| [ctl:forceResponseBodyVariable](#ctlforceresponsebodyvariable) | Engine-specific | - | - | yes | Coraza: populate RESPONSE_BODY regardless of MIME type |
| [ctl:hashEnforcement](#ctlhashenforcement) | Deprecated | yes | - | yes | Hash enforcement for this transaction |
| [ctl:hashEngine](#ctlhashengine) | Deprecated | yes | - | yes | Hash engine for this transaction |
| [ctl:parseXmlIntoArgs](#ctlparsexmlintoargs) | Extended | yes | yes | - | XML values into ARGS for this transaction |
| [ctl:requestBodyAccess](#ctlrequestbodyaccess) | Core | yes | yes | yes | Request body access for this transaction |
| [ctl:requestBodyLimit](#ctlrequestbodylimit) | Extended | yes | - | yes | Request body limit for this transaction |
| [ctl:requestBodyProcessor](#ctlrequestbodyprocessor) | Core | yes | yes | yes | Select the body processor |
| [ctl:responseBodyAccess](#ctlresponsebodyaccess) | Extended | yes | - | yes | Response body access for this transaction |
| [ctl:responseBodyLimit](#ctlresponsebodylimit) | Extended | yes | - | yes | Response body limit for this transaction |
| [ctl:responseBodyProcessor](#ctlresponsebodyprocessor) | Engine-specific | - | - | yes | Coraza: select the response body processor |
| [ctl:ruleEngine](#ctlruleengine) | Core | yes | yes | yes | Rule engine mode for this transaction |
| [ctl:ruleRemoveById](#ctlruleremovebyid) | Core | yes | yes | yes | Disable rules by id for this transaction |
| [ctl:ruleRemoveByMsg](#ctlruleremovebymsg) | Extended | yes | - | yes | Disable rules by message for this transaction |
| [ctl:ruleRemoveByTag](#ctlruleremovebytag) | Core | yes | yes | yes | Disable rules by tag for this transaction |
| [ctl:ruleRemoveTargetById](#ctlruleremovetargetbyid) | Core | yes | yes | yes | Exclude a variable from rules by id |
| [ctl:ruleRemoveTargetByMsg](#ctlruleremovetargetbymsg) | Extended | yes | - | yes | Exclude a variable from rules by message |
| [ctl:ruleRemoveTargetByTag](#ctlruleremovetargetbytag) | Core | yes | yes | yes | Exclude a variable from rules by tag |

## Core actions

### allow

**Status:** Core

**Syntax.** `allow`, `allow:phase`, `allow:request`

**Semantics.** Disruptive. `allow` stops rule processing for the current phase and
every later phase except logging (phase 5), which MUST still run. `allow:phase` stops
only the current phase. `allow:request` stops phases 1 and 2 (the response phases still
run). `allow` produces no interruption object in any engine (it sets a flag); tests
observe it through which rules do and do not run.

**Divergence notes.** Coraza 3.8.1 (`internal/corazawaf/rulegroup.go`, `AllowTypeAll`)
also skips the logging phase, so its phase 5 rules do not run after `allow`
(`compat/known-gaps.md`).

**Tests.** `tests/engine/actions/allow.yaml`

### auditlog

**Status:** Core

**Syntax.** `auditlog`

**Semantics.** Marks the transaction as relevant for audit logging when the rule
matches (used with `SecAuditEngine RelevantOnly`). No effect on rule evaluation.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### block

**Status:** Core

**Syntax.** `block`

**Semantics.** A placeholder for the disruptive action inherited from `SecDefaultAction`
(`03-processing-model.md#disruptive-actions`). With `SecDefaultAction "...,deny"` a
`block` rule denies; with none inherited it passes. CRS uses it on every blocking rule so
that `SecDefaultAction` decides between blocking and detection.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/block-with-default.yaml`,
`tests/engine/actions/block-without-default.yaml`

### capture

**Status:** Core

**Syntax.** `capture`

**Semantics.** After an `@rx` match, stores the whole match in `TX:0` and capture groups
1 to 9 in `TX:1`…`TX:9`. Also defined for `@detectSQLi` (fingerprint in `TX:0`). Values
persist until the next capturing match.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/capture-multimatch.yaml`,
`tests/engine/variables/tx-and-capture.yaml`

### chain

**Status:** Core

**Syntax.** `chain`

**Semantics.** Makes the next rule a member of this rule's chain
(`03-processing-model.md#chains`).

**Divergence notes.** None known.

**Tests.** `tests/engine/processing/chain.yaml`

### ctl

**Status:** Core

**Syntax.** `ctl:OPTION=VALUE`

**Semantics.** Changes engine configuration for the current transaction when the rule
matches (`03-processing-model.md#ctl-timing`). Option names match case-insensitively.
Each option is specified below under `ctl:OPTION`; statuses are fixed by ADR-0006.

**Divergence notes.** See the individual options.

**Tests.** `tests/engine/actions/ctl-options.yaml`,
`tests/engine/processing/ctl-core-options-load.yaml`

### deny

**Status:** Core

**Syntax.** `deny`

**Semantics.** Disruptive: interrupts the transaction with the status from `status:`,
default 403 (`03-processing-model.md#disruptive-actions`).

**Divergence notes.** None known.

**Tests.** `tests/engine/processing/disruptive-actions.yaml`

### drop

**Status:** Core

**Syntax.** `drop`

**Semantics.** Disruptive: closes the connection without a response where the host
allows, otherwise behaves as `deny`. Reported as `action: drop`.

**Divergence notes.** None known.

**Tests.** `tests/engine/processing/disruptive-actions.yaml`

### id

**Status:** Core

**Syntax.** `id:N`, `N` a positive integer; `id:'N'` is also accepted.

**Semantics.** The rule's identifier, mandatory and unique (ADR-0015). Used by every
exclusion mechanism and by logs.

**Divergence notes.** See ADR-0015 for Coraza's default build.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`,
`tests/engine/grammar/secrule-requires-id.yaml`

### log

**Status:** Core

**Syntax.** `log`

**Semantics.** Writes the match to the engine's error log and, unless `noauditlog`
is present, marks the transaction for the audit log. The default when neither `log`
nor `nolog` is given.

**Divergence notes.** Coraza 3.8.1 logs a match only when `log` is given explicitly or
inherited from `SecDefaultAction` (`internal/corazawaf/transaction.go`, `r.Log`); CRS
sets `log` in its default actions, so this is rarely visible. Recorded in
`compat/known-gaps.md` under unobservable divergences.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### logdata

**Status:** Core

**Syntax.** `logdata:'TEXT'` (macros expand).

**Semantics.** Additional text written with the log message, typically the matched
value (`%{MATCHED_VAR}`): macros are expanded when the rule matches and the result is
written as the `[data "TEXT"]` field of the rule's error-log line
(`10-logging.md#error-log`); a rule with `nolog` writes nothing. No effect on evaluation.

**Divergence notes.** Truncation and escaping of the text differ
(`10-logging.md#error-log`): v2 cuts at 512 bytes, v3 at 200 bytes and hex-escapes
non-printable bytes, Coraza escapes with Go's `%q`.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`, `tests/engine/logging/logdata.yaml`

### msg

**Status:** Core

**Syntax.** `msg:'TEXT'` (macros expand).

**Semantics.** The rule's log message; also the target of `SecRuleRemoveByMsg`.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### multiMatch

**Status:** Core

**Syntax.** `multiMatch`

**Semantics.** Evaluates the operator against the value before any transformation and
again after each transformation in the `t:` list, instead of only against the final
value. The rule matches if any evaluation matches.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/capture-multimatch.yaml`

### noauditlog

**Status:** Core

**Syntax.** `noauditlog`

**Semantics.** The match does not mark the transaction as relevant for audit logging.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### nolog

**Status:** Core

**Syntax.** `nolog`

**Semantics.** The match is not written to the error log and implies `noauditlog`
unless `auditlog` is also given. The rule still counts as triggered (`tests/README.md`).

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### pass

**Status:** Core

**Syntax.** `pass`

**Semantics.** The non-interrupting disruptive action: processing continues with the
next rule.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### phase

**Status:** Core

**Syntax.** `phase:1`…`phase:5`, `phase:request`, `phase:response`, `phase:logging`

**Semantics.** The phase the rule runs in (`03-processing-model.md#phases`); default 2
(ADR-0017).

**Divergence notes.** See ADR-0017.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`,
`tests/engine/processing/phases.yaml`

### redirect

**Status:** Core

**Syntax.** `redirect:URL` (macros expand).

**Semantics.** Disruptive: interrupts with a redirect to `URL`; the status is the
`status:` value when it is 301, 302, 303 or 307, otherwise 302.

**Divergence notes.** libmodsecurity v3 (`src/actions/disruptive/redirect.cc`) also
honours 304, 305 and 306; portable rules use the four codes above.

**Tests.** `tests/engine/actions/status-redirect.yaml`,
`tests/engine/processing/disruptive-actions.yaml`

### setvar

**Status:** Core

**Syntax.** `setvar:COLL.key=VALUE`, `setvar:COLL.key=+N`, `setvar:COLL.key=-N`,
`setvar:!COLL.key`, `setvar:COLL.key` (sets `1`). Macros expand in `VALUE`.

**Semantics.** Creates or replaces a member of a writable collection (`TX`, and the
persistent collections where Extended). `=+N` and `=-N` convert the current value to an
integer, treating an unset or non-numeric value as 0, add or subtract `N`, and store the
decimal result. `!` deletes the member. Names are matched case-insensitively (ADR-0008).

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/setvar.yaml`

### severity

**Status:** Core

**Syntax.** `severity:N` with `N` 0–7, or one of `EMERGENCY ALERT CRITICAL ERROR
WARNING NOTICE INFO DEBUG` (case-insensitive), optionally quoted.

**Semantics.** Metadata written to logs; lowers `HIGHEST_SEVERITY` (Extended) when
smaller than its current value.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/severity.yaml`

### skipAfter

**Status:** Core

**Syntax.** `skipAfter:LABEL`

**Semantics.** On match, skip to the `SecMarker LABEL` in the current phase; a rule id is
not a label (`03-processing-model.md#flow-control`, ADR-0016, ADR-0028). An engine SHOULD
warn at load time when no `SecMarker LABEL` follows the rule.

**Divergence notes.** See ADR-0016 and ADR-0028.

**Tests.** `tests/engine/actions/skipafter.yaml`

### status

**Status:** Core

**Syntax.** `status:N`

**Semantics.** The HTTP status code used by `deny` (any code) and `redirect` (3xx only).
No effect with other disruptive actions.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/status-redirect.yaml`

### t

**Status:** Core

**Syntax.** `t:NAME`

**Semantics.** Appends transformation `NAME` (`07-transformations.md`) to the rule's
list; `t:none` resets the inherited list. Repeatable.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`,
`tests/engine/actions/t-none.yaml`

### tag

**Status:** Core

**Syntax.** `tag:'TEXT'` (macros expand). Repeatable.

**Semantics.** Metadata written to logs and the target of `SecRuleRemoveByTag`,
`SecRuleUpdateTargetByTag` and `ctl:ruleRemoveByTag`.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

### ver

**Status:** Core

**Syntax.** `ver:'TEXT'`

**Semantics.** Rule set version metadata written to logs.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/metadata-and-log-actions.yaml`

## Core ctl options

### ctl:auditEngine

**Status:** Core

**Syntax.** `ctl:auditEngine=On|Off|RelevantOnly`

**Semantics.** Overrides `SecAuditEngine` for this transaction.

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:auditLogParts

**Status:** Core

**Syntax.** `ctl:auditLogParts=+LETTERS` or `-LETTERS`

**Semantics.** Adds or removes audit log parts for this transaction. The absolute form
(`=ABCZ`) is Extended (ADR-0006).

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:forceRequestBodyVariable

**Status:** Core

**Syntax.** `ctl:forceRequestBodyVariable=On|Off`

**Semantics.** When set in phase 1, `REQUEST_BODY` is populated regardless of the body
processor or content type.

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:requestBodyAccess

**Status:** Core

**Syntax.** `ctl:requestBodyAccess=On|Off`

**Semantics.** Overrides `SecRequestBodyAccess` for this transaction; effective only in
phase 1.

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:requestBodyProcessor

**Status:** Core

**Syntax.** `ctl:requestBodyProcessor=URLENCODED|XML|JSON`

**Semantics.** Selects the request body processor regardless of `Content-Type`;
effective only in phase 1. Names match case-insensitively. `MULTIPART` is accepted by
ModSecurity v2 and Coraza but not by libmodsecurity v3 (`seclang-scanner.ll` defines only
the three values above), so it is Extended.

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:ruleEngine

**Status:** Core

**Syntax.** `ctl:ruleEngine=On|Off|DetectionOnly`

**Semantics.** Overrides `SecRuleEngine` for the later phases and, at once, for the
interruption decision of the current phase: after `DetectionOnly` or `Off` no later rule
of the phase interrupts (`03-processing-model.md#ctl-timing`). After `Off` no further
rule of the transaction is evaluated, so the mode cannot be switched back (ADR-0034).

**Divergence notes.** libmodsecurity v3 and Coraza read the mode only when a phase starts:
they evaluate the rest of the phase after `Off`, and a later `ctl:ruleEngine` in it
overwrites `Off` (`compat/known-gaps.md`).

**Tests.** `tests/engine/actions/ctl-options.yaml`,
`tests/engine/processing/ctl-timing.yaml`,
`tests/engine/processing/ctl-ruleengine-off-final.yaml`

### ctl:ruleRemoveById

**Status:** Core

**Syntax.** `ctl:ruleRemoveById=ID` or `=A-B`

**Semantics.** Disables the matching rules for the rest of this transaction
(`03-processing-model.md#rule-exceptions`).

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:ruleRemoveByTag

**Status:** Core

**Syntax.** `ctl:ruleRemoveByTag=TAG`

**Semantics.** Disables every rule one of whose `tag` values equals `TAG` for the rest of
this transaction (`03-processing-model.md#rule-exceptions`, ADR-0029).

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:ruleRemoveTargetById

**Status:** Core

**Syntax.** `ctl:ruleRemoveTargetById=ID;TARGET` (`ID` may be a range `A-B`)

**Semantics.** Excludes `TARGET` (a variable with optional key, e.g. `ARGS:password`)
from the matching rules for the rest of this transaction. This is the mechanism CRS
documents for per-request exclusions.

**Tests.** `tests/engine/actions/ctl-options.yaml`

### ctl:ruleRemoveTargetByTag

**Status:** Core

**Syntax.** `ctl:ruleRemoveTargetByTag=TAG;TARGET`

**Semantics.** As `ctl:ruleRemoveTargetById`, selecting every rule one of whose `tag`
values equals `TAG` (ADR-0029).

**Tests.** `tests/engine/actions/ctl-options.yaml`

## Extended actions

### accuracy

**Status:** Extended

**Semantics.** Rule accuracy 1–9, metadata only.

**Implemented by.** v2, v3, Coraza.

### exec

**Status:** Extended

**Semantics.** Runs an external script or Lua file when the rule matches; process access makes it Extended.

**Implemented by.** v2, v3, Coraza.

### expirevar

**Status:** Extended

**Semantics.** `expirevar:COLL.key=SECONDS`: removes a persistent variable after the interval (ADR-0007).

**Implemented by.** v2, v3, Coraza.

### initcol

**Status:** Extended

**Semantics.** `initcol:ip=%{REMOTE_ADDR}`: initialises a persistent collection (ADR-0007).

**Implemented by.** v2, v3, Coraza.

### maturity

**Status:** Extended

**Semantics.** Rule maturity 1–9, metadata only.

**Implemented by.** v2, v3, Coraza.

### rev

**Status:** Extended

**Semantics.** Rule revision string, metadata only.

**Implemented by.** v2, v3, Coraza.

### sanitizeArg

**Status:** Extended

**Syntax.** `sanitizeArg:NAME`.

**Semantics.** When the rule matches, marks every argument of the transaction (query string
or request body) whose name equals `NAME`, compared case-insensitively, so that its value
is written to the logs as the mask `[sanitized]`, whatever its length. Wherever the engine
writes a marked argument or header, or text derived from it, to the transaction's audit log
entry (request line and URI, headers, bodies, matched-rule messages) or to an error-log
line written by this rule or a later rule of the same transaction (the URI or query string
in the line, a macro in `msg` or `logdata`, the matched-data description), the value MUST
NOT appear in clear. The same bytes arriving in another field are not marked. In the audit
log the mask takes the value's place; where the
mask appears in the error log is engine-specific. An engine that cannot locate a marked
value inside a body it writes MUST write the whole body as the mask. Error-log lines
written before the action ran are not retracted, the debug log is not masked, and the
variables keep their values for later rules. Non-disruptive (ADR-0033).

**Divergence notes.** ModSecurity v2 (`apache2/re_actions.c`, `apache2/msc_logging.c`
`sanitize_request_line`) masks the audit log only and writes one `*` per byte, which shows
the length. libmodsecurity v3.0.17 rejects the action (`ACTION_NOT_SUPPORTED` in
`src/parser/seclang-parser.yy`); Coraza v3.8.1 does not know it.

**Tests.** `tests/engine/actions/sanitize.yaml`

**Implemented by.** v2 (same-length mask, audit log only).

### sanitizeMatched

**Status:** Extended

**Syntax.** `sanitizeMatched`.

**Semantics.** Marks, as `08-actions.md#sanitizearg` describes, the value the rule matched
when the matched variable is `ARGS:x`, `ARGS_GET:x`, `ARGS_POST:x` or `ARGS_NAMES:x` (the
value of argument `x`),
`REQUEST_HEADERS:x` or `REQUEST_HEADERS_NAMES:x` (request header `x`), or
`RESPONSE_HEADERS:x` or `RESPONSE_HEADERS_NAMES:x` (response header `x`). For any other
variable it does nothing (ADR-0033).

**Divergence notes.** As for `sanitizeArg`; v2 (`msre_action_sanitizeMatched_execute`)
handles `ARGS`, `ARGS_NAMES` and the header collections but not `ARGS_GET` or `ARGS_POST`.

**Tests.** `tests/engine/actions/sanitize.yaml`

**Implemented by.** v2 (same-length mask, audit log only).

### sanitizeMatchedBytes

**Status:** Extended

**Syntax.** `sanitizeMatchedBytes` or `sanitizeMatchedBytes:N/M`, with `N` and `M` single
digits.

**Semantics.** As `sanitizeMatched`, but marks only the bytes the operator matched inside
the value; the rest of the value stays in clear. With `N/M` the first `N` and the last `M`
matched bytes stay in clear and the bytes between them are written as one `[sanitized]`
(ADR-0033).

**Divergence notes.** As for `sanitizeArg`; v2 parses `N/M` in
`msre_action_sanitizeMatchedBytes_init`.

**Tests.** `tests/engine/actions/sanitize.yaml`

**Implemented by.** v2 (same-length mask, audit log only).

### sanitizeRequestHeader

**Status:** Extended

**Syntax.** `sanitizeRequestHeader:NAME`.

**Semantics.** Marks, as `08-actions.md#sanitizearg` describes, the value of every request
header whose name equals `NAME`, compared case-insensitively (ADR-0033).

**Divergence notes.** As for `sanitizeArg`.

**Tests.** `tests/engine/actions/sanitize.yaml`

**Implemented by.** v2 (same-length mask, audit log only).

### sanitizeResponseHeader

**Status:** Extended

**Syntax.** `sanitizeResponseHeader:NAME`.

**Semantics.** Marks, as `08-actions.md#sanitizearg` describes, the value of every response
header whose name equals `NAME`, compared case-insensitively (ADR-0033).

**Divergence notes.** As for `sanitizeArg`.

**Tests.** `tests/engine/actions/sanitize.yaml`

**Implemented by.** v2 (same-length mask, audit log only).

### setenv

**Status:** Extended

**Semantics.** Sets a variable in the host process environment for downstream modules.

**Implemented by.** v2, v3, Coraza.

### setrsc

**Status:** Extended

**Semantics.** Initialises the `RESOURCE` persistent collection (ADR-0007).

**Implemented by.** v2, v3.

### setsid

**Status:** Extended

**Semantics.** Initialises the `SESSION` persistent collection and `SESSIONID` (ADR-0007).

**Implemented by.** v2, v3.

### setuid

**Status:** Extended

**Semantics.** Initialises the `USER` persistent collection and `USERID` (ADR-0007).

**Implemented by.** v2, v3.

### skip

**Status:** Extended

**Semantics.** `skip:N`: skips the next N rules in the phase (`03-processing-model.md#flow-control`); all three engines implement it, CRS does not use it.

**Implemented by.** v2, v3, Coraza.

### xmlns

**Status:** Extended

**Semantics.** Declares an XML namespace prefix for XPath selectors in `XML:`.

**Implemented by.** v2, v3.


## Deprecated actions

### append

**Status:** Deprecated

**Semantics.** Appends text to the response body; needs `SecContentInjection`.

**Implemented by.** v2.

### deprecatevar

**Status:** Deprecated

**Semantics.** Decrements a persistent variable over time.

**Implemented by.** v2.

### marker

**Status:** Deprecated

**Semantics.** Internal action created by `SecMarker`; never written by rule authors.

**Implemented by.** v2.

### pause

**Status:** Deprecated

**Semantics.** Delays the response by milliseconds.

**Implemented by.** v2.

### prepend

**Status:** Deprecated

**Semantics.** Prepends text to the response body; needs `SecContentInjection`.

**Implemented by.** v2.

### proxy

**Status:** Deprecated

**Semantics.** Proxies the request to another URL (Apache `mod_proxy`).

**Implemented by.** v2.

## Extended ctl options

### ctl:debugLogLevel

**Status:** Extended

**Semantics.** `ctl:debugLogLevel=N` for this transaction.

**Implemented by.** v2, Coraza.

### ctl:parseXmlIntoArgs

**Status:** Extended

**Semantics.** `ctl:parseXmlIntoArgs=On|Off|OnlyArgs` for this transaction.

**Implemented by.** v2, v3.

### ctl:requestBodyLimit

**Status:** Extended

**Semantics.** `ctl:requestBodyLimit=BYTES` for this transaction.

**Implemented by.** v2, Coraza.

### ctl:responseBodyAccess

**Status:** Extended

**Semantics.** `ctl:responseBodyAccess=On|Off` for this transaction.

**Implemented by.** v2, Coraza.

### ctl:responseBodyLimit

**Status:** Extended

**Semantics.** `ctl:responseBodyLimit=BYTES` for this transaction.

**Implemented by.** v2, Coraza.

### ctl:ruleRemoveByMsg

**Status:** Extended

**Semantics.** Disables rules whose `msg` matches, for this transaction.

**Implemented by.** v2, Coraza.

### ctl:ruleRemoveTargetByMsg

**Status:** Extended

**Semantics.** Excludes a target from rules whose `msg` matches, for this transaction.

**Implemented by.** v2, Coraza.


## Deprecated ctl options

### ctl:hashEnforcement

**Status:** Deprecated

**Semantics.** Hash enforcement toggle for this transaction (Deprecated hash engine).

**Implemented by.** v2, Coraza.

### ctl:hashEngine

**Status:** Deprecated

**Semantics.** Hash engine toggle for this transaction (Deprecated hash engine).

**Implemented by.** v2, Coraza.


## Engine-specific ctl options

### ctl:forceResponseBodyVariable

**Status:** Engine-specific

**Semantics.** Coraza: populates `RESPONSE_BODY` regardless of MIME type.

**Implemented by.** Coraza.

### ctl:responseBodyProcessor

**Status:** Engine-specific

**Semantics.** Coraza: selects the response body processor (`JSON`, `XML`, …).

**Implemented by.** Coraza.

