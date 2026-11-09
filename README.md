# SecLang Specification

Published at <https://seclang.org/> (built from this repository by
`.github/workflows/pages.yml`; see `site/README.md`).

A formal specification of **SecLang**, the rule language implemented by
[ModSecurity](https://github.com/owasp-modsecurity/ModSecurity) (v2 and libmodsecurity
v3) and [Coraza](https://github.com/corazawaf/coraza), with engine-neutral conformance
tests and Architecture Decision Records for the places where engines diverge.

**Status: Draft 0.1 (2026-10-07).** The specification covers the whole language in
`spec/00` to `spec/10`: conventions, lexical structure, grammar, processing model,
directives, variables, operators, transformations, actions, body processors and logging.
It ships 98 engine-tier test profiles and 62 unit-tier files holding about
4,280 cases, 21 ADRs (all `proposed`), a three-engine compatibility matrix and a
table of the Core tests each engine fails today. The engines surveyed were ModSecurity
v2 (`v2/master`, 2026-09), libmodsecurity v3.0.17 and Coraza v3.8.1.

## Layout

| Path | What |
|---|---|
| `spec/` | The specification, one file per topic. Every feature heading has a `**Status:**` line. |
| `adr/` | Decisions. `Divergence` ADRs pick a behaviour where engines disagree and name the test that encodes it. |
| `tests/` | Conformance test data (no runner). `unit/` for operators and transformations, `engine/` for everything else. |
| `compat/` | Three-engine feature matrix (`matrix.json`, rendered by `tools/matrix.py`) and `known-gaps.md`, the Core tests each engine is known to fail today. |
| `docs/superpowers/` | The design document and the per-phase implementation plans this draft was built from. |
| `tools/` | `validate.py` enforces the repo's invariants; CI runs it. `import_sts.py` regenerates the unit tier from the SecRules Test Set. |
| `adapters/` | Reference adapters that run `tests/` against a real engine (ADR-0023). `adapters/coraza` runs Coraza v3.8.1 and `adapters/libmodsecurity` runs libmodsecurity v3.0.17 in CI, with `compat/known-gaps.md` as the expected-failure list. |
| `formal/` | Lean 4 model of the specification, run in CI: every transformation of spec 07 and every library-free operator of spec 06 against the unit-tier corpus (`lake exe seclang-check`), a parser for the configuration grammar of spec 01–04 against every engine profile (`lake exe seclang-parse`), and the processing model of spec 03 with URL-encoded, multipart and JSON bodies and the body limits run against the profiles' transactions (`lake exe seclang-eval`), with theorems for ADR-0016 and ADR-0017. |

## Status labels

`Core` MUST be implemented. `Extended` SHOULD be, and is declared per engine.
`Deprecated` MUST parse and MAY be ignored. `Engine-specific` is reserved, not specified.
Definitions: `spec/00-conventions.md`. Rationale: `adr/0001-status-labels-and-core.md`.

## Running the checks

Requires Python 3.10 or newer (CI runs 3.12) and [uv](https://docs.astral.sh/uv/).

```sh
uv sync
uv run python tools/validate.py
uv run python -m unittest discover -s tools -t .
```

## Implementing an engine adapter

Read `tests/README.md`. Load every file under `tests/unit` and `tests/engine`, skip
engine profiles whose `requires` lists a feature you do not implement, and assert the
`output` blocks. Report the spec version you conform to.

## Contributing

Open an ADR for any behavioural decision; add or update tests in the same change; run
the validator. The design document is in `docs/superpowers/specs/`.

## How an engine adopts this

1. Write an adapter that loads `tests/unit` and `tests/engine` (`tests/README.md`),
   skipping engine profiles whose `requires:` names an Extended feature you do not
   implement. `adapters/coraza` is a complete example in about 500 lines of Go.
2. Compare your failures with `compat/known-gaps.md`; a failure not listed there is either
   a bug in your engine or a bug in this specification. Open an issue for the latter.
3. Review the ADRs; two engines agreeing moves an ADR from `proposed` to `accepted`.
