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
| `adapters/` | Reference adapters that run `tests/` against a real engine (ADR-0023). `adapters/coraza` runs Coraza v3.8.1, `adapters/libmodsecurity` runs libmodsecurity v3.0.17 and `adapters/modsecurity2` runs ModSecurity v2.9.15 under Apache in CI, with `compat/known-gaps.md` as the expected-failure list. |
| `action.yml` | GitHub Action that runs the reference adapter for Coraza, libmodsecurity v3 or ModSecurity v2 against an engine checkout, for the engines' own CI (below). |
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

## Testing an engine in its own CI

`action.yml` builds the engine from the calling repository's checkout and runs this
repository's reference adapter against it: the engine and unit tiers, gated by
`compat/known-gaps.md`. A failure no row lists fails the job. A listed test that now passes
is reported as a warning (`obsolete-gaps: warn`, the default), so fixing a gap never breaks
the build; open an issue here to drop the row.

```yaml
# .github/workflows/seclang.yml in corazawaf/coraza
jobs:
  seclang:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: fzipi/seclang-spec@<commit SHA>   # pin: new tests land on main
        with:
          engine: coraza
```

| Engine | `engine:` | Checkout | What the action does |
|---|---|---|---|
| Coraza | `coraza` | the repository root | points the adapter's `go.mod` at the checkout (`replace`), then `go test` |
| libmodsecurity v3 | `libmodsecurity` | with `submodules: recursive` (Mbed TLS has its own) | `build.sh`, `configure` with libxml2, yajl and PCRE2 and the debug log enabled, `make install` under `$RUNNER_TEMP`, then the Python adapter over the C API; run it in its own job, since it reconfigures the tree |
| ModSecurity v2 | `modsecurity2` | with `submodules: recursive` | builds `adapters/modsecurity2/Dockerfile` with the checkout as the `modsecurity2-src` build context, then runs the adapter under Apache in that image |

`source:` takes another path when the engine is not checked out at the workspace root. Pin
the action to a commit or tag: the tests and `compat/known-gaps.md` change on `main`, and the
pinned version is the specification the engine is said to conform to.
`.github/workflows/conformance-action.yml` runs the action here against the versions the
adapters pin.
