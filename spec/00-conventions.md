# 00. Conventions

**Document status.** Draft 0.1 (2026-10-07). Files 00–10 cover the whole language as
implemented by the three surveyed engines. An ADR is `proposed` until the maintainers of
at least two implementing engines agree, then `accepted` (`adr/README.md` lists each one's
status).
`compat/known-gaps.md` lists the Core tests each engine fails today.

This specification describes SecLang, the rule language shared by ModSecurity v2,
libmodsecurity v3, Coraza and any future engine. It standardizes what the engines
already agree on and, where they diverge, records a decision as an ADR in `adr/`.

## Requirement words

"MUST", "MUST NOT", "SHOULD", "SHOULD NOT" and "MAY" are used as defined in RFC 2119
and RFC 8174, and carry that meaning only when written in capitals.

## Feature status

Every directive, variable, operator, transformation, action and `ctl:` option in this
specification, and any other level-3 section that carries a status line (lexical rules,
processor and logging contracts), is a *feature* and carries exactly one status, written
as the first non-blank line after its `###` heading, `**Status:** <value>`:

| Status            | Meaning for an implementing engine |
|-------------------|------------------------------------|
| `Core`            | MUST be implemented as specified. Conformance requires every Core feature. Every Core feature has at least one test in `tests/`. |
| `Extended`        | SHOULD be implemented. Fully specified. An engine declares which Extended features it supports; tests for them carry `requires:` so other engines skip them. |
| `Deprecated`      | MUST be accepted by the parser. MAY be ignored with a warning. MUST NOT be used in new rulesets. Engines that reject one today are listed in `compat/known-gaps.md`. |
| `Engine-specific` | Listed so the name is reserved. Not specified here; another engine MUST NOT give the name different semantics. |

The initial Core set is the intersection of the three surveyed engines, restricted to
features used by OWASP CRS v4 or by the engines' recommended configuration files.
Promoting a feature to Core needs an ADR (see ADR-0001).


## Spec versioning

The specification is versioned `vMAJOR.MINOR`. Adding features, or moving a feature
between `Extended`, `Deprecated` and `Engine-specific`, is a MINOR change. Changing the
semantics of a Core feature, or promoting to or demoting from Core, is MAJOR and
requires an ADR.

## Conformance statement

An engine conforms to `seclang-spec vX.Y` when it passes every test under `tests/` that
is not skipped by a `requires:` clause for an Extended feature it does not declare.
Core tests can never be skipped. `compat/known-gaps.md` lists the Core tests each
surveyed engine fails today, so that a gap is a tracked bug rather than a surprise.

An engine-tier profile that needs an Extended feature lists that feature's anchor under
`requires:` (`NN-file.md#anchor`); every entry MUST resolve to a feature whose status is
`Extended`, which `tools/validate.py` enforces. Unit-tier cases carry no `requires:`:
a unit case belongs to the feature named by its `spec:` anchor, and an engine skips the
case when that feature is Extended and not declared by the engine.

## Reading this document

Each feature section is organized as: **Syntax**, **Default** (where applicable),
**Scope** (where a directive may appear), **Semantics**, **Divergence notes** (links to
ADRs), **Tests** (paths under `tests/`).

## Source anchors

Tests reference features by `NN-file.md#anchor`, where `anchor` is the GitHub heading
slug: lowercase the heading, drop every character that is not a letter, digit,
underscore, space or hyphen, then replace spaces with hyphens. `tools/validate.py` enforces that every
reference resolves and every Core feature is referenced.
