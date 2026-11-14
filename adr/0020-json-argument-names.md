# ADR-0020: JSON argument names are unspecified

- **Status:** accepted
- **Date:** 2026-10-07
- **Accepted:** 2026-11-14
- **Deciders:** @fzipi, @airween, @franbuehler, @xanadu, @theseion
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

OWASP CRS targets `ARGS` and `ARGS_NAMES` as a whole and never names a JSON path, but its
results still depend on the scheme, because the separator and the prefix are text the
client never sent. CRS rule 930120 matches `ARGS_NAMES` against `lfi-os-files.data`, whose
entries include dotfiles (`.forward`, `.boto`, `.credentials`, `.secrets`). With v3 and
Coraza the body `{"forward":"x"}` yields the name `json.forward` and the rule matches; with
v2 the name is `forward` and it does not. With v2 the same false positive appears only for
a nested key, such as `{"data":{"forward":"x"}}` (`data.forward`). The same request is
therefore a false positive on one engine and clean on another (OWASP CRS issues 4810 and
4871). The CRS fix for the original report, pull request 4812, is itself scheme-specific:
it excludes `ARGS_NAMES:/^json\.profile[.\w\-]*$/` from 930120, which names nothing under
v2 (list entries checked against CRS `main` at bd624a82d). A rule author writing `ARGS:json.user.role`
today works on one engine only.

## Decision

The set of leaf values and their count are normative; the member names are not. A rule
that needs a specific JSON leaf MUST match `ARGS_NAMES` with an expression anchored at the
end of the name (for example `(?:^|\.)role$`) or inspect `ARGS` as a whole. Engines
SHOULD document their scheme, and no test asserts a name.

The names in `ARGS` are not expected to converge. Structured access to JSON is to come
from a separate collection, as XML already has `XML` with XPath selectors: a future
Extension ADR is to add `JSON`, selected with a subset of RFC 9535 JSONPath, and
`JSON_NAMES`, whose values are the object keys as the client sent them. Taking JSON out
of `ARGS` would be a later Divergence ADR, written once OWASP CRS targets the new
collection.

## Options considered

- Pick the `json.` prefix with dotted object paths, which v3 and Coraza already share.
  The prefix is text the client never sent (the 930120 case above), and it tells a rule
  nothing that `ARGS_POST` and `REQBODY_PROCESSOR` do not; rejected.
- Pick v2's bare paths, dropping the prefix. One exclusion would then cover form and JSON
  bodies, and flat keys would stop gaining a `.`. Nested keys still do
  (`{"data":{"forward":"x"}}` is `data.forward`), `{"a.b":1}` and `{"a":{"b":1}}` still
  share a name, and v3 and Coraza must change; rejected.
- Escape `.` and `\` inside keys with a backslash. Names become unambiguous, but a rule
  for a key at any depth then needs a regular expression that parses the whole name,
  because a `.` preceded by an odd number of backslashes is not a separator and RE2,
  which Coraza uses, has no lookbehind. Portable rules cannot write `\\`
  (`01-lexical.md#quoted-arguments`), and `t:normalizePathWin` turns the added `\` into
  `/`; rejected.
- RFC 9535 Normalized Paths (`$['user']['name']`) as `ARGS` names: unambiguous, but every
  name then carries `'` and `[`, which the SQL injection rules that inspect `ARGS_NAMES`
  count; rejected.
- A separate `JSON` collection with JSONPath selectors and raw-key names: no added text
  reaches an operator, `$..role` finds a key at any depth without a regular expression,
  and form fields and JSON keys never share a collection. Deferred to its own Extension
  ADR (see the Decision).
- Leave the `ARGS` names unspecified (chosen).

## Consequences

- For rule authors: never write `ARGS:json.x` or `ARGS:x` for JSON leaves in portable
  rules. The anchored expression `(?:^|\.)role$` also matches a single key named
  `x.role`, because a name cannot tell a dot in a key from a separator.
- For rule authors: a pattern applied to `ARGS_NAMES` that starts with `.` or contains
  `json` can match text the engine added, not text the client sent; such a rule behaves
  differently on each engine for JSON bodies.
- For engines: no change now.

## Tests

- `tests/engine/body/json-args.yaml` (asserts count, a value and an anchored name regex)

## References

- `spec/09-body-processors.md#json`
- OWASP CRS issues 4810 and 4871, pull request 4812 (coreruleset/coreruleset): rule 930120
  false positives on JSON argument names
