# ADR-0003: Test formats: SecRules Test Set JSON for units, go-ftw-derived YAML for engine profiles

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

Three machine-readable test corpora already exist for SecLang engines:

- The SecRules Test Set (`SpiderLabs/secrules-language-tests`, vendored as a submodule
  by libmodsecurity v3): JSON arrays of `{type, name, param, input, output, ret}`
  cases for operators and transformations. Both ModSecurity v3 and Coraza have
  runners for this shape.
- libmodsecurity v3 regression tests (`test/test-cases/regression/*.json`): a full
  synthetic transaction plus expected debug-log substrings and HTTP code. Tied to v3
  debug-log wording.
- go-ftw YAML (`coreruleset/go-ftw`, documented in `waf-test-spec/YAMLFormat.md`) and
  Coraza's in-tree `testing/profile` Go structs, which mirror it and add `rules`,
  `triggered_rules`, `non_triggered_rules` and `interruption`.

This repository must stay runner-free (design assumption 4), so the formats must be
loadable by Go and C++ test code with off-the-shelf libraries.

## Decision

Two tiers, both with a JSON Schema in `tests/schema/`:

1. **Unit tier**, `tests/unit/**/*.json`: the SecRules Test Set field names, plus
   optional `spec`, `note` and `re_groups` fields. Two deliberate differences from the
   corpus: `input`, `output` and `param` are plain JSON strings with no second layer of
   backslash escapes (libmodsecurity's runner decodes `\\xHH` and `\\uHHHH` in `input` and
   `output` after parsing, to one byte each, and nothing else; `tools/import_sts.py`
   applies exactly that model once, on import), and they are byte strings: every code
   point is at most U+00FF and denotes one byte, which the validator enforces, so adapters
   encode them with Latin-1.
2. **Engine tier**, `tests/engine/**/*.yaml`: one profile per file in the Coraza
   profile / go-ftw shape (`meta`, `rules`, `tests[].stages[].stage.{input,output}`),
   plus `spec`, `requires`, a `stage.response` block for synthetic backend responses,
   and `output.no_interruption`.

Assertions are limited to rule IDs, interruption and log substrings. Audit-log layout,
debug-log wording and timing are never asserted.

The validator uses two Python dev dependencies, `pyyaml` and `jsonschema`, because
YAML parsing and JSON Schema 2020-12 validation are not worth reimplementing and both
are available in every CI image.

## Options considered

- Invent a new unified format: nothing can run it on day one; rejected.
- JSON for the engine tier too: one parser fewer, but go-ftw users write YAML and the
  multi-line `rules` block is unreadable as a JSON string; rejected.
- Reuse v3 regression JSON: assertions depend on v3 debug-log wording; rejected.
- stdlib-only validator: would need a hand-written YAML subset parser and schema
  checker; rejected as more code than the rest of the repo.

## Consequences

- For ModSecurity: the unit tier is already runnable; the engine tier needs a small
  adapter over the existing regression harness (`test/regression`).
- For Coraza: `testing/profile` already loads the engine tier minus `response`,
  `requires`, `spec` and `no_interruption`; add those fields and a skip on `requires`.
- For contributors: write YAML/JSON, run `python3 tools/validate.py`, no toolchain.

## Tests

- `tests/unit/transformations/base64Decode.json`
- `tests/engine/directives/secruleengine-on.yaml`

## References

- `tests/README.md`
- https://github.com/coreruleset/go-ftw
- https://github.com/SpiderLabs/secrules-language-tests
