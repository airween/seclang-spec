# ADR-0033: The `sanitize*` actions are Extended and mask with a fixed string

- **Status:** proposed
- **Date:** 2026-11-09
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

ADR-0011 made the five `sanitize*` actions Deprecated with the other v2 legacy features,
because only ModSecurity v2 implements them. They are still the only way a rule can keep a
password, token or card number out of the logs, and losing them pushes operators towards
turning off audit logging or request-body parts altogether. The engines today:

- ModSecurity v2 (`v2/master` 2026-09, `apache2/re_actions.c`
  `msre_action_sanitizeArg_execute`, `msre_action_sanitizeMatched_execute`,
  `msre_action_sanitizeMatchedBytes_init`; `apache2/msc_logging.c` `sanitize_request_line`
  and the part writers): masks in the audit log only (request line, request headers,
  URL-encoded and multipart request bodies, response headers), replacing every byte of the
  value with `*`, so the value's length stays visible. The error log is not masked:
  `%{MATCHED_VAR}` in `msg` or `logdata` writes the clear value.
- libmodsecurity v3.0.17: the lexer recognises the names, but `src/parser/seclang-parser.yy`
  rejects them with `ACTION_NOT_SUPPORTED`, so a rule using one fails to load.
- Coraza v3.8.1: no such actions (`internal/actions`); a rule using one fails to load.
- OWASP CRS v4.25.2 does not use them.

## Decision

The five actions move from `Deprecated` to `Extended` (`08-actions.md#sanitizearg` and the
four entries after it). The American spelling `sanitize*` is canonical and `sanitise*` is a
required alias (ADR-0004):

- `sanitizeArg:NAME` marks every argument (query string or request body) whose name equals
  `NAME`, compared case-insensitively. `sanitizeRequestHeader:NAME` and
  `sanitizeResponseHeader:NAME` mark every request or response header of that name.
  `sanitizeMatched` marks what the rule matched when the variable is `ARGS:x`,
  `ARGS_GET:x`, `ARGS_POST:x`, `ARGS_NAMES:x`, `REQUEST_HEADERS:x`, `REQUEST_HEADERS_NAMES:x`, `RESPONSE_HEADERS:x` or
  `RESPONSE_HEADERS_NAMES:x` (the value of argument or header `x`), and does nothing for any
  other variable. `sanitizeMatchedBytes` marks only the bytes the operator matched inside
  that value; `sanitizeMatchedBytes:N/M` leaves the first `N` and the last `M` of them in
  clear.
- A marked value is written as the fixed mask `[sanitized]`, whatever its length, wherever
  the engine writes that argument or header, or text derived from it, to the transaction's
  audit log entry (request line and URI, headers, request and response bodies,
  matched-rule messages) or to an error-log line written by the rule that marks it or by a
  later rule in the same transaction: the URI or query string in a line, a macro in `msg` or
  `logdata`, the description of the matched data. The same bytes arriving in another field
  (a `Referer` that repeats the password) are not marked. An engine that cannot locate a marked
  value inside a body it writes MUST write that whole body as the mask. Error-log lines
  written before the action ran are not retracted. The debug log is out of scope.
- The positive form is fixed only for the audit log: where the value would appear in an
  audit part the engine writes `[sanitized]` there. Where the mask appears in the error log
  is engine-specific; only the absence of the clear value is normative.
- The actions are non-disruptive, run when the rule matches, and change only logging; the
  variables keep their values for later rules.

## Options considered

- Keep them Deprecated (ADR-0011): leaves rules with no portable way to keep secrets out of
  the logs; rejected.
- `ARGS_GET` and `ARGS_POST` added to v2's variable list for `sanitizeMatched`: a rule
  matching `ARGS_POST:password` is as likely as one matching `ARGS:password`.
- `sanitise*` canonical, as ADR-0011 and the earlier spec entries wrote it: v2 registers both
  spellings alike and names its own functions `msre_action_sanitize*`; rejected in favour of
  the American spelling, with the British one kept as an alias so no ruleset breaks.
- Specify v2's behaviour as is: a same-length mask leaks the length, which is enough to tell
  a PIN from a password and to confirm a guessed value, and v2 leaves the error log in clear;
  rejected.
- Fixed mask in both logs (chosen): v2 needs a change, but the requirement is testable as
  the absence of the clear value plus one fixed string in the audit log.
- Mask the debug log too: debug output is for development, has no shared format, and is
  rarely enabled in production; out of scope.

## Consequences

- For ModSecurity v2: write `[sanitized]` instead of one `*` per byte, and apply the marks
  to error-log lines and to macro expansion in `msg` and `logdata`.
- For libmodsecurity v3: register the actions instead of `ACTION_NOT_SUPPORTED` and apply
  the marks in the audit log writer and in `RuleMessage`.
- For Coraza: add the actions in `internal/actions` and apply the marks in its audit log
  writers and its error-log output.
- For this repository: the actions are Extended before any engine declares them, so their
  profiles are skipped everywhere until one does; `00-conventions.md#status-transitions`
  gains a row for restoring a Deprecated feature. The test schema gains
  `audit_log_contains`/`no_audit_log_contains` (`tests/README.md`), and the rule of
  ADR-0021 that log assertions use only `msg` text gains one exception: `no_log_contains`
  and `no_audit_log_contains` with a marked value, and `audit_log_contains` with the mask.
- For rule authors: `sanitizeArg:password` and its siblings are portable once two engines
  ship them; until then they load only in v2, and v2 output still shows the length.

## Tests

- `tests/engine/actions/sanitize.yaml`

## References

- ADR-0004, ADR-0011, ADR-0021, ADR-0032
- `spec/08-actions.md#sanitizearg`, `spec/10-logging.md`, `tests/README.md`
