# ADR-0001: Status labels and the meaning of Core

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Clarification

## Context

No prior specification exists. A survey on 2026-10-06 of ModSecurity v2 (`v2/master`),
libmodsecurity v3.0.16 and Coraza v3.8.1 found 91 directive names, 48 actions, 20
`ctl:` options, 44 operators, 38 transformations and 144 variables in the union, of
which 65, 33, 10, 28, 33 and 74 respectively exist in all three (`compat/matrix.md`).
Some union members are legacy (`sanitise*`, `PERF_*`), some are engine extensions
(`SecDataset`, `rxGlobal`), and some are accepted by a parser without being
implemented. A single "supported / not supported" axis cannot express this.

## Decision

Every feature carries exactly one of four statuses, defined normatively in
`spec/00-conventions.md`: **Core** (MUST implement), **Extended** (SHOULD implement,
fully specified, declared per engine), **Deprecated** (MUST parse, MAY ignore),
**Engine-specific** (name reserved, not specified).

The initial Core set is the intersection of the three surveyed engines **restricted
to** features used by OWASP CRS v4 or by the engines' recommended configuration files.
A feature in the intersection but unused by CRS v4 starts as Extended. Moving a feature
into or out of Core requires an ADR.

Conformance is all-or-nothing for Core and declared per feature for Extended.

## Options considered

- Union as Core: forces every engine to implement every legacy feature; rejected.
- Intersection as Core, unfiltered: makes e.g. `SecGsbLookupDb` Core although nothing
  uses it; rejected.
- Intersection filtered by CRS v4 usage: chosen. CRS v4 is the one ruleset every engine
  already claims to run, so it is the practical definition of compatibility.
- A numeric conformance level (1, 2, 3): hides which features differ; rejected.

## Consequences

- For ModSecurity: v2-only features will be labelled Deprecated or Engine-specific.
- For Coraza: features it lacks but CRS uses (if any are found in Phase 2–3) become
  Core gaps to close; persistent collections are Extended (ADR-0007, Phase 3).
- For rule authors: a ruleset using only Core features is portable by construction.

## Tests

Not applicable; this ADR defines process. Enforcement is `tools/validate.py`, which
fails when a Core feature has no test.

## References

- `docs/superpowers/specs/2026-10-06-seclang-spec-design.md` sections 2 and 4.2
- `compat/matrix.md`
