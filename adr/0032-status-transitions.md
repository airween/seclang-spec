# ADR-0032: When a feature changes status

- **Status:** proposed
- **Date:** 2026-11-09
- **Deciders:** @fzipi
- **Category:** Clarification

## Context

ADR-0001 defines the four statuses and the rule for the initial Core set: the intersection of
the three surveyed engines, restricted to what OWASP CRS v4 or the engines' recommended
configurations use. It says moving a feature into or out of Core needs an ADR, but not when a
feature should move at all, and nothing says when an `Engine-specific` name becomes
`Extended`. Engines keep adding features: libmodsecurity v3.0.17 added
`MULTIPART_DUPLICATE_PART_HEADER`, `MULTIPART_FILENAME_CHARSET` and
`MULTIPART_FILENAME_LANGUAGE`, which Coraza already had, leaving three `Engine-specific`
variables with two implementations.

The current split in `compat/matrix.json` (2026-11-09) shows the practice the statuses grew
from: every `Extended` feature has two or three implementations (57 and 77), every `Core`
feature three (one with a known gap), and `Engine-specific` names one, apart from the three
variables above.

## Decision

Status transitions are defined in `spec/00-conventions.md#status-transitions`:

- `Engine-specific` to `Extended` when at least two engines implement the feature
  compatibly, its entry has full Syntax and Semantics, and a test exercises it. This is a
  MINOR change with no ADR, unless the engines disagree on what would be specified, which
  needs a Divergence ADR first.
- `Extended` to `Core` when all three surveyed engines implement it and OWASP CRS v4 or an
  engine's recommended configuration uses it, through an ADR (MAJOR). An engine that fails
  its tests gets a `compat/known-gaps.md` row.
- Demotions from Core, and moves to `Deprecated`, need an ADR (precedents ADR-0025 and
  ADR-0011). A feature left with fewer than two implementations returns to
  `Engine-specific`.

## Options considered

- `Extended` only when all three engines implement it: 57 `Extended` features have two
  implementations, so they would have to be grandfathered or demoted, and "SHOULD, declared
  per engine" already covers an engine that lacks one; rejected.
- At least two engines for `Extended` (chosen): matches current practice and the two-engine
  rule for accepting an ADR.
- `Core` on CRS use alone: would make an engine non-conforming as soon as CRS adopts a
  feature it lacks; rejected in favour of the ADR-0001 rule, all three engines and CRS use.

## Consequences

- For engines: adding a feature a second engine already has is the step that makes it
  portable (`Extended`).
- For this repository: the three multipart variables above meet the `Extended` rule once
  their entries are fully specified and tested.
- For rule authors: `Core` remains what a portable ruleset may rely on; `Extended` means two
  or more engines, declared per engine.

## Tests

None; this records process. `tools/validate.py` already enforces that `requires:` names only
`Extended` features and that every `Core` feature has a test.

## References

- ADR-0001, ADR-0011, ADR-0025
- `spec/00-conventions.md#status-transitions`
