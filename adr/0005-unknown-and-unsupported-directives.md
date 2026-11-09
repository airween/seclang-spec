# ADR-0005: Unknown versus unsupported directives

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

- ModSecurity v2: an unknown directive is an Apache configuration error; the server does
  not start.
- libmodsecurity v3: the parser rejects an unknown directive and the configuration fails
  to load.
- Coraza 3.8.1: `internal/seclang/parser.go` rejects an unknown directive (`unknown
  directive %q`), but `directivesmap.gen.go` maps seven *known* names to
  `directiveUnsupported`, which returns `nil` without logging: `SecArgumentSeparator`,
  `SecCookieFormat`, `SecRuleUpdateTargetByMsg`, `SecRuleScript`, `SecRulePerfTime`,
  `SecTmpDir` and `secunicodemap`. `SecRemoteRules` returns an error instead.
  `SecIgnoreRuleCompilationErrors On` makes rule compilation errors non-fatal; it does
  not affect unknown directives.

Two of the silently ignored names, `SecArgumentSeparator` and `SecRequestBodyNoFilesLimit`
(the latter parsed into a field with a `TODO`), are Core in this specification and change
what rules see. A user who sets them and gets no warning has a false sense of coverage.

## Decision

1. A directive name that this specification does not define MUST be a configuration
   error.
2. A directive whose status is Deprecated, or Extended and not implemented by the engine,
   MUST be accepted; the engine MAY ignore it and SHOULD log a warning naming the
   directive once per configuration load.
3. A directive that is Engine-specific to *another* engine is "not defined" for this
   engine (rule 1) unless the engine documents that it accepts it.
4. A Core directive MUST be implemented. Accepting a Core directive without implementing
   its semantics is non-conforming; the engine's conformance statement MUST list it as a
   known gap until fixed.

## Options considered

- Ignore every unknown directive (lenient): hides typos and misconfigurations; rejected.
- Error on anything unimplemented (strict): makes Deprecated features unusable across
  engines even where they are harmless; rejected.
- Error on unknown, accept-and-warn on known-but-unimplemented (chosen): matches what
  users of both engines already expect for `#`-commented legacy directives.

## Consequences

- For ModSecurity v2: no change.
- For libmodsecurity v3: it rejects several Deprecated and Extended names outright
  (`seclang-parser.yy`, "is not supported": `SecServerSignature`,
  `SecCacheTransformations`, `SecChrootDir`, `SecGsbLookupDb`, `SecGuardianLog`,
  `SecStreamInBodyInspection`, `SecStreamOutBodyInspection`, `SecHashKey`,
  `SecHashParam`, `SecHashMethodRx`, `SecHashMethodPm`, and the `On` value of
  `SecHashEngine`, `SecInterceptOnError`, `SecContentInjection`,
  `SecRuleInheritance`, `SecDisableBackendCompression`), which rule 2 forbids; it should
  accept and warn. Where it parses and ignores (e.g. `SecConnEngine Off`) it should warn.
- For Coraza: fourteen Deprecated names are unknown to its parser (`compat/matrix.md`,
  `-` in the Coraza column), which rule 2 forbids; add them as accepted-and-warned.
- For Coraza: log a warning in `directiveUnsupported`; implement `SecArgumentSeparator`
  and `SecRequestBodyNoFilesLimit` or list them as gaps.
- For rule authors: a Deprecated directive in a shared configuration is safe on every
  engine; a misspelled one is caught everywhere.

## Tests

- `tests/engine/directives/unknown-directive.yaml`
- `tests/engine/directives/deprecated-directive-accepted.yaml`

## References

- `spec/04-directives.md` index (statuses), `spec/00-conventions.md`
