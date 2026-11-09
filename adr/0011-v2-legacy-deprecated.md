# ADR-0011: ModSecurity v2 legacy features are Deprecated

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Deprecation

## Context

ModSecurity v2 is an Apache module and carries features tied to that host or to retired
services: the `PERF_*` and `SCRIPT_*` variables, `STREAM_INPUT_BODY`/`STREAM_OUTPUT_BODY`
with `@rsub`, `WEBSERVER_ERROR_LOG`, `USERAGENT_IP`, `SDBM_DELETE_ERROR`,
`MULTIPART_CRLF_LINE`; the actions `append`, `prepend`, `proxy`, `pause`, `deprecatevar`,
`marker`, `sanitise*`; the directives already marked Deprecated in `04-directives.md`
(`SecChrootDir`, `SecGuardianLog`, `SecHash*`, `SecConn*`, `SecGsbLookupDb`,
`SecStatusEngine`, …); and the operators `@gsbLookup` and `@rsub` (the latter only
operates on the Deprecated `STREAM_*` variables). libmodsecurity v3 parses many of
them and rejects some; Coraza does not know most of them. No current ruleset uses them.

## Decision

These features are Deprecated. Engines MUST accept the names (a directive loads, an
action or operator parses, a variable may be selected) and MAY ignore them, SHOULD log a
warning once per configuration load, and MUST NOT give them new semantics. They MUST NOT
appear in new rulesets. ADR-0005 governs how unknown and unsupported directives are
reported; `compat/known-gaps.md` lists where an engine rejects a Deprecated name today.

## Options considered

- Engine-specific (v2): would let v3 or Coraza redefine the names; rejected.
- Remove from the specification: shared configurations containing them would become
  non-portable errors; rejected.
- Deprecated (chosen).

## Consequences

- For libmodsecurity v3: the names it rejects with "not supported" should be accepted
  and warned instead (ADR-0005 consequences list them).
- For Coraza: add the unknown Deprecated names as accepted-and-warned.
- For rule authors: a legacy rule set keeps loading everywhere, doing nothing where the
  feature is absent.

## Tests

- `tests/engine/directives/deprecated-directive-accepted.yaml`

## References

- `spec/04-directives.md`, `spec/05-variables.md`, `spec/06-operators.md`, `spec/08-actions.md`
