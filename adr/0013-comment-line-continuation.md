# ADR-0013: Comment lines ending in a backslash

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

Rule authors comment out a multi-line rule by prefixing its first line with `#`:

```
# SecRule ARGS "@rx evil" \
    "id:1,phase:1,deny"
```

- ModSecurity v2: Apache's configuration reader joins continuation lines before the
  directive processor tests for `#`, so the whole logical line is a comment.
- libmodsecurity v3: `src/parser/seclang-scanner.ll` has explicit rules for
  `# SecRule … \` and `# SecAction … \` that enter a comment state consuming the
  continued lines.
- Coraza 3.8.1: `internal/seclang/parser.go` discards a line starting with `#` *before*
  checking for a trailing backslash, so `"id:1,phase:1,deny"` is parsed as a directive
  on its own and fails to load, or, for a continued action list that happens to start
  with a directive name, loads as a different rule.

## Decision

Line continuation is applied before comment detection. A comment line ending in `\`
continues onto the next physical line and the whole logical line is the comment. Engines
MUST NOT parse the continued text as a directive. This is normative in
`spec/01-lexical.md#comments`.

## Options considered

- Coraza's order (comment first): a commented-out rule can come back to life, which is a
  security-relevant surprise; rejected.
- ModSecurity's order (chosen): matches two engines, Apache, and the mental model
  "prefix the first line with `#` to disable the rule".

## Consequences

- For ModSecurity: no change.
- For Coraza: swap the two checks in `parseLine`, or strip the trailing backslash of a
  comment line and keep consuming until a line without one.
- For rule authors: commenting out the first line of a rule disables all of it on every
  engine.

## Tests

- `tests/engine/lexical/comment-with-trailing-backslash.yaml`

## References

- `spec/01-lexical.md#comments`, `spec/01-lexical.md#line-continuation`
