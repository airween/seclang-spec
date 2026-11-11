# ADR-0040: A `?` prefix names a variable the engine may not know

- **Status:** proposed
- **Date:** 2026-11-11
- **Deciders:** @fzipi
- **Category:** Extension

## Context

A variable name the engine does not define is a configuration error
(`02-grammar.md#variable-list`), and one such rule stops the whole configuration from
loading. ModSecurity v2, libmodsecurity v3 and Coraza all reject an unknown name at load
time (`tests/engine/grammar/unknown-variable.yaml` passes on all three). So a ruleset
can't use a variable that only newer engines have, such as the ones ADR-0038 and ADR-0039
add, without splitting into one edition per engine. CRS ships one edition for all
engines and would like to keep it that way (round table, meeting 01).

The SecLang round table notes sketch three ways out:

- a variable marker, `SecRule ?FUTURE_VAR "@rx ..."`, which "makes parser ignore the
  variable if it's not known";
- a `SecRuleOptional` directive;
- a `skipParserAfter` action that skips parsing up to a marker when a version check
  fails.

## Decision

1. A variable entry MAY be prefixed with `?`, after any `&` or `!`: `?NAME`, `?NAME:key`,
   `&?NAME`, `!?NAME:key`.
2. If the engine defines `NAME`, the `?` changes nothing.
3. If it does not, the entry MUST NOT be a configuration error. It selects no values, so
   `&?NAME` counts 0, and `!?NAME` removes nothing. The engine SHOULD log, once per
   configuration load, that the variable is unknown.
4. Without `?`, an unknown name stays a configuration error.

A rule whose only target is unknown never matches, except through `&?NAME`. To run
something only where the variable exists, test `&?NAME "@eq 0"` and `skipAfter` past it.

## Options considered

- **`?` on the variable (chosen).** It is limited to the one name the engine may not
  know, so a misspelt name without `?` is still caught at load time.
- **`SecRuleOptional`, a directive whose rule is dropped if anything in it is unknown.**
  Rejected: it also hides misspelt operators and actions, and every directive that
  takes a variable list would need an optional twin.
- **`skipParserAfter`, skipping parsing up to a marker on a version check.** Rejected:
  it evaluates a rule while the configuration is still being parsed, which no engine
  does, and it ties the ruleset to version numbers rather than to the variable it needs.
- **Make every unknown name a warning.** Rejected: a misspelt variable would load as a
  rule that never matches, silently.
- **`<IfDefine>`.** Apache only; see ADR-0039.

## Consequences

- For ModSecurity v2, libmodsecurity v3 and Coraza: the variable-list parser accepts `?`.
- For rule authors:
  - Engines released before this change reject `?` itself, so a ruleset can only rely on
    it once every engine it supports parses it.
  - The first rulesets to use it still need one edition for older engines.
  - From then on, new variables can be adopted without another edition.

## Tests

None until an engine implements it; then a grammar profile: an unknown `?NAME` loads and
selects nothing, `&?NAME` counts 0, and an unknown name without `?` still fails to load.

## References

- SecLang round table notes, "Variables and their behavior":
  https://docs.google.com/document/d/1ZmVuc8TYk7ylUnhU0vp06WeZq_QqCw6XlmRssEaHDv0
- `02-grammar.md#variable-list`, ADR-0005, ADR-0039
