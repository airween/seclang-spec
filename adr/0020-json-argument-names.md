# ADR-0020: JSON argument names are unspecified

- **Status:** proposed
- **Date:** 2026-10-07
- **Deciders:** @fzipi
- **Category:** Clarification

## Context

All three engines flatten a JSON request body into argument members, one per scalar leaf,
but name them differently. Observed on 2026-11-11 through the three reference adapters
with the body `{"a":1,"b":{"c":"x"},"d":[1,2],"e":[{"f":1}],"g":[[1]]}` and the
top-level array `[1,{"h":2}]`:

| Leaf | ModSecurity v2 | libmodsecurity v3 | Coraza |
|---|---|---|---|
| `a` | `a` | `json.a` | `json.a` |
| `b.c` | `b.c` | `json.b.c` | `json.b.c` |
| `d[0]`, `d[1]` | `d.d`, `d.d` | `json.d.array_0`, `json.d.array_1` | `json.d.0`, `json.d.1` |
| `e[0].f` | `e.e.f` | `json.e.array_0.f` | `json.e.0.f` |
| `g[0][0]` | `g.g.g` | `json.g.array_0.array_0` | `json.g.0.0` |
| top-level `[0]`, `[1].h` | `array.array`, `array.array.h` | `json.array_0`, `json.array_1.h` | `json.0`, `json.1.h` |
| extra members | none | none | one per array holding its length: `json.d`, `json.e`, `json.g`, `json.g.0`; `json` for a top-level array |

- ModSecurity v2 (v2.9.15, `apache2/msc_json.c`): the key path joined with `.`, no
  prefix; an array element repeats the array's key.
- libmodsecurity v3 (v3.0.17): `getCurrentKey()` in `src/request_body_processor/json.h`
  returns `json` for the root, and `JSON::addArgument` in `json.cc` joins the container
  names with `.` and names array elements `array_N`. The first version of this ADR read
  `json.cc` alone and described v3 as dot-prefixed (`.b.c`); the adapter run corrected
  it.
- Coraza (v3.8.1, `internal/bodyprocessors/json.go`, `readItems`): the `json.` prefix,
  array elements numbered from 0, and the length members above.

v3 and Coraza therefore agree on the `json.` prefix and on dotted object paths; they
differ on array elements (`array_0` against `0`) and on Coraza's length members. v2 differs
on all three.

OWASP CRS targets `ARGS` and `ARGS_NAMES` as a whole and never names a JSON path, so no
published ruleset depends on the scheme. A rule author writing `ARGS:json.user.role`
today works on one engine only.

## Decision

The set of leaf values and their count are normative; the member names are not. A rule
that needs a specific JSON leaf MUST match `ARGS_NAMES` with an expression anchored at the
end of the name (for example `(?:^|\.)role$`) or inspect `ARGS` as a whole. Engines
SHOULD document their scheme. A future Divergence ADR may standardise a scheme once an
engine is prepared to change; until then no test asserts a name.

## Options considered

- Pick the `json.` prefix with dotted object paths, which v3 and Coraza already share:
  self-describing and collision-free with form fields. It leaves array element names and
  Coraza's length members to settle, and it breaks v2 exclusions written against bare
  paths; deferred to the Divergence ADR below, but the closest scheme to agreement.
- Pick v2's bare paths: the oldest scheme, but collides with form field names and
  neither v3 nor Coraza implements it; deferred.
- Leave unspecified (chosen).

## Consequences

- For rule authors: never write `ARGS:json.x` or `ARGS:x` for JSON leaves in portable
  rules.
- For engines: no change now.

## Tests

- `tests/engine/body/json-args.yaml` (asserts count, a value and an anchored name regex)

## References

- `spec/09-body-processors.md#json`
