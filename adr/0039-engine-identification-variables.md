# ADR-0039: Engine identification variables and behaviour flags

- **Status:** proposed
- **Date:** 2026-11-11
- **Deciders:** @fzipi
- **Category:** Extension

## Context

A ruleset that has to load on several engines, or on versions from both sides of a
breaking change such as ADR-0038, needs to know which engine and which behaviour it runs
on. Today it can't:

- ModSecurity v2 (v2/master, 2026-09): `MODSEC_BUILD` (`apache2/re_variables.c`,
  `var_modsec_build_generate`; `modsec_build` in `apache2/msc_util.c`) is nine digits:
  two each for major, minor and maintenance version, one for the build type, two for the
  release.
- libmodsecurity v3 (v3.0.17): `MODSEC_BUILD` (`src/variables/modsec_build.h`) is eight
  digits: two each for major, minor, patch level and tag number.
- Coraza (v3.8.1): no such variable.

The two `MODSEC_BUILD` formats differ in length and neither names the engine, so a rule
can't compare them across engines. OWASP CRS v4.25.2 does not use `MODSEC_BUILD`.

The SecLang round table (meeting 01, 2024-03-13) discussed this. Christian Folini
proposed engine-neutral `ENGINE_NAME`, `ENGINE_VERSION`, `ENGINE_BUILD` and an
`ENGINE_FLAGS` collection; the notes then split the version into
`ENGINE_VERSION_MAJOR`, `_MINOR` and `_PATCH` and give `ENGINE_FLAGS:uri_decoding_new`
as an example flag. Marc Stern proposed `<IfDefine MODSEC_…>` compile-time flags for
ModSecurity on Apache, which cost nothing at run time. Juan Pablo Tosso proposed
compile-time flags with the same names and behaviour in ModSecurity and Coraza for
transition periods.

## Decision

The following Extended variables are defined. Each is set before phase 1 and is the same
for every transaction of a loaded configuration.

1. `ENGINE_NAME`: scalar, a lower-case token naming the implementation: `modsecurity` for
   ModSecurity v2, `libmodsecurity` for libmodsecurity v3, `coraza` for Coraza. Other
   implementations choose their own token, which MUST NOT be one of these.
2. `ENGINE_VERSION_MAJOR`, `ENGINE_VERSION_MINOR`, `ENGINE_VERSION_PATCH`: scalars, each a
   base-10 integer without leading zeros, so `@eq`, `@lt` and `@ge` compare them.
3. `ENGINE_BUILD`: scalar, free-form build information (pre-release tag, commit, build
   type). Rules SHOULD NOT parse it.
4. `ENGINE_FLAGS`: collection. Each member is a behaviour defined by an ADR, named in
   lower case with underscores, with the value `1` when the engine behaves as that ADR
   decides and `0` when it does not yet. A flag the engine does not know is absent, so
   `&ENGINE_FLAGS:NAME` is 0. The ADR that introduces a behaviour change names its flag.
   This ADR defines one:
   - `uri_decoding`: `1` when `REQUEST_URI`, `REQUEST_FILENAME` and `REQUEST_BASENAME`
     are percent-decoded as ADR-0038 decides.
5. `MODSEC_BUILD` is unchanged.

A ruleset branches on a flag, not on a version. Here the decoding rule runs only where the
engine does not decode, including engines that define `ENGINE_FLAGS` but not this flag.
On an engine without `ENGINE_FLAGS` the first rule is a configuration error; ADR-0040
proposes `?ENGINE_FLAGS:uri_decoding` for that case.

```
SecRule ENGINE_FLAGS:uri_decoding "@eq 1" "id:1000,phase:1,pass,nolog,skipAfter:URI_DECODED"
SecRule REQUEST_URI "@rx ..." "id:1001,phase:1,block,t:urlDecodeUni"
SecMarker URI_DECODED
```

## Options considered

- **Flags plus split version numbers (chosen).** A flag tracks a behaviour, so backports,
  distribution patches and forks are covered without a version table. The numbers are
  for the cases no flag covers.
- **Version checks only.** Rejected: every ruleset would carry a table of which version
  of which engine changed what, wrong as soon as a distribution backports a fix.
- **One `ENGINE_VERSION` string.** Rejected: operators can't compare `3.0.17` against
  `3.0.9` as numbers.
- **Reuse `MODSEC_BUILD`.** Rejected: two formats already, no engine name, and the name
  belongs to ModSecurity.
- **`<IfDefine MODSEC_…>` compile-time flags.** Not a SecLang feature: `<IfDefine>` is an
  Apache configuration section, so libmodsecurity v3 connectors other than Apache and
  Coraza can't offer it. Engines MAY still provide it next to these variables; this
  specification leaves it Engine-specific.
- **The round table's `uri_decoding_new` as the flag name.** Renamed to `uri_decoding`:
  the flag outlives the transition, and "new" stops being true.

## Consequences

- For ModSecurity v2, libmodsecurity v3 and Coraza: five new variables; `ENGINE_FLAGS`
  grows with each ADR that changes behaviour.
- For rule authors: one ruleset can load on both sides of a breaking change. Until every
  engine in use defines these variables, a rule naming them is a configuration error on
  the others (`02-grammar.md#variable-list`); ADR-0040 proposes a way to name a variable
  the engine may not know.

## Tests

None until an engine implements the variables; then an engine profile, with `requires:`
naming them, that checks each value's form and `&ENGINE_FLAGS:NAME` for an unknown flag.

## References

- SecLang round table notes, meeting 01 (2024-03-13) and "Variables and their behavior":
  https://docs.google.com/document/d/1ZmVuc8TYk7ylUnhU0vp06WeZq_QqCw6XlmRssEaHDv0
- `05-variables.md#modsec_build`, ADR-0038
