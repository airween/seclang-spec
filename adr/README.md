# Architecture Decision Records

An ADR records a decision about the SecLang specification: what was decided, which
alternatives existed, and why. Write one whenever the engines disagree and the spec
has to pick (Divergence), when behaviour is undocumented but agreed (Clarification),
when a legacy feature is retired (Deprecation), or when an engine-specific feature is
promoted into the spec (Extension).

## Process

1. Copy `0000-template.md` to `NNNN-short-slug.md` with the next free number.
2. Fill every header field. `Status` is `proposed` until maintainers of at least two
   implementing engines agree, then `accepted`, with an `Accepted` date line under `Date`.
   `superseded` and `rejected` are terminal.
3. A `Divergence` ADR must list at least one test under `## Tests` that encodes the
   outcome. The validator checks the paths exist.
4. Add a row to the index below. `uv run python tools/validate.py` fails if a file and the
   index disagree.
5. Update the affected section of `spec/` in the same PR.

## Index

| ADR | Title | Category | Status |
|---|---|---|---|
| [0001](0001-status-labels-and-core.md) | Status labels and the meaning of Core | Clarification | accepted |
| [0002](0002-case-insensitive-names.md) | Directive, operator, action and transformation names match case-insensitively | Divergence | accepted |
| [0003](0003-test-formats.md) | Test formats: SecRules Test Set JSON for units, go-ftw-derived YAML for engine profiles | Clarification | accepted |
| [0004](0004-canonical-names-and-aliases.md) | Canonical names and required aliases | Divergence | proposed |
| [0005](0005-unknown-and-unsupported-directives.md) | Unknown versus unsupported directives | Divergence | accepted |
| [0006](0006-core-ctl-options.md) | Core `ctl:` options | Divergence | proposed |
| [0007](0007-persistent-collections.md) | Persistent collections are Extended | Divergence | accepted |
| [0008](0008-collection-key-case.md) | Collection keys match case-insensitively | Divergence | accepted |
| [0009](0009-phase-evaluation-model.md) | Strict per-phase evaluation is normative; early evaluation must be invisible | Clarification | accepted |
| [0010](0010-engine-specific-names-reserved.md) | Engine-specific names are reserved | Clarification | accepted |
| [0011](0011-v2-legacy-deprecated.md) | ModSecurity v2 legacy features are Deprecated | Deprecation | accepted |
| [0012](0012-uppercase-transformation.md) | `uppercase` is promoted to Core | Extension | accepted |
| [0013](0013-comment-line-continuation.md) | Comment lines ending in a backslash | Divergence | accepted |
| [0014](0014-secdefaultaction-constraints.md) | `SecDefaultAction` constraints | Divergence | proposed |
| [0015](0015-mandatory-rule-id.md) | Every rule carries an id | Divergence | accepted |
| [0016](0016-skipafter-scope.md) | `skipAfter` scope ends with the phase | Divergence | accepted |
| [0017](0017-default-phase.md) | The default phase is 2 and is never inherited | Divergence | accepted |
| [0018](0018-regex-dialect.md) | Core regular-expression syntax is the RE2-compatible subset | Divergence | accepted |
| [0019](0019-duration-units.md) | `DURATION` is Extended with unspecified units | Clarification | proposed |
| [0020](0020-json-argument-names.md) | JSON argument names are unspecified | Clarification | proposed |
| [0021](0021-logging-contract.md) | The portable logging contract is rule ids, messages and logdata | Clarification | accepted |
| [0022](0022-request-body-without-processor.md) | `REQUEST_BODY` without a body processor | Divergence | accepted |
| [0023](0023-reference-adapters.md) | Reference adapters live in this repository | Clarification | accepted |
| [0024](0024-ipmatch-invalid-entries.md) | Unparsable `@ipMatch` entries are configuration errors | Divergence | accepted |
| [0025](0025-secrequestbodyinmemorylimit-extended.md) | `SecRequestBodyInMemoryLimit` is Extended, not Core | Divergence | accepted |
| [0026](0026-compresswhitespace-nbsp.md) | `compressWhitespace` treats the byte 0xA0 as whitespace | Divergence | accepted |
| [0027](0027-rx-compile-mode.md) | `@rx` is compiled dot-all; line anchors need `(?m)` | Divergence | accepted |
| [0028](0028-skipafter-label-is-a-marker.md) | `skipAfter` resolves to a `SecMarker`, never to a rule id | Divergence | accepted |
| [0029](0029-tag-exceptions-exact.md) | Tag and message rule exceptions select by exact string | Divergence | accepted |
| [0030](0030-negation-per-value.md) | A negated operator applies per value | Clarification | accepted |
| [0031](0031-htmlentitydecode-named-entities.md) | `htmlEntityDecode` decodes the ASCII named entities of the WHATWG table | Divergence | accepted |
| [0032](0032-status-transitions.md) | When a feature changes status | Clarification | accepted |
| [0033](0033-sanitize-actions-extended.md) | The `sanitize*` actions are Extended and mask with a fixed string | Divergence | proposed |
| [0034](0034-ruleengine-off-is-final.md) | `ctl:ruleEngine=Off` is final for the transaction | Divergence | proposed |
| [0035](0035-noauditlog-relevance-only.md) | `noauditlog` affects relevance only; the audit record lists every logged match | Divergence | proposed |
| [0036](0036-parameterised-transformations.md) | Parameterised transformations, defined by name | Extension | proposed |
| [0037](0037-count-applies-to-scalars.md) | `&` applies to every variable and counts a scalar as 1 | Divergence | proposed |
