# ADR-0044: `JSON` and `JSON_NAMES` hold a JSON body, selected with JSONPath

- **Status:** proposed
- **Date:** 2026-11-14
- **Deciders:** @fzipi
- **Category:** Extension

## Context

A JSON request body reaches rules only through `ARGS`, under names each engine builds
differently (ADR-0020): `b.c` in ModSecurity v2, `json.b.c` in libmodsecurity v3 and
Coraza, with three spellings for array elements. The names cannot be standardised inside
`ARGS` without new problems. The `json.` prefix and the `.` separator are text the client
never sent, and OWASP CRS rule 930120 matches them (CRS issues 4810 and 4871). A plain
dotted name cannot tell `{"a.b":1}` from `{"a":{"b":1}}`. Escaping the dot makes a key at
any depth hard to match with a regular expression. RFC 9535 Normalized Paths put `'` and `[`
into every name that the SQL injection rules inspect. ADR-0020 records these options and
leaves the `ARGS` names unspecified.

XML already avoids the problem. The XML body processor fills the `XML` collection, which is
selected with XPath (`05-variables.md#xml`), and CRS adds `XML:/*` to its target lists
next to `ARGS`. No engine has an equivalent for JSON today.

RFC 9535 defines JSONPath, a query language for JSON, and the Normalized Path, a JSONPath
expression that names exactly one node (`$['user']['roles'][0]`).

## Decision

1. **`JSON`.** When the JSON body processor parsed the request body
   (`09-body-processors.md#json`), the `JSON` collection holds one member for each scalar
   (string, number, `true`, `false`, `null`) in the document, in document order. The
   member's value is the same text the scalar gives in `ARGS`. Its name is the scalar's
   Normalized Path (RFC 9535 §2.7), for example `$['user']['roles'][0]`. When the JSON
   body processor did not run, the collection is empty.
2. **`JSON_NAMES`.** The `JSON_NAMES` collection holds one member for each object member
   in the document, in document order. The member's value is the key's decoded string,
   with nothing added: no prefix, separator, quote or escape. Its name is the Normalized
   Path of that object member's value. Each occurrence of a repeated key gives its own
   member.
3. **Selectors.** The selector of `JSON` and `JSON_NAMES` is a JSONPath query in the
   following subset of RFC 9535: the root `$`; name selectors, in bracket notation
   (`['k']`) or member-name shorthand (`.k`); non-negative index selectors (`[0]`); the
   wildcard (`[*]`, `.*`); and the descendant segment (`..`). Filter expressions, slices,
   negative indexes, unions and function extensions are not in the subset. A selector
   outside it is a configuration error. The query is evaluated over the document. `JSON`
   yields the members whose node it selects; a selected object or array yields nothing
   itself, so the scalars under `$['user']` are written `$['user']..*`. `JSON_NAMES`
   yields the members whose value node it selects, so `JSON_NAMES:$..role` yields every
   key named `role`. Names compare byte for byte, without case folding, because JSON keys
   are case-sensitive. A regular-expression selector (`JSON:/^\$\['user'\]/`) matches the
   Normalized Path of each member, as for any collection.
4. **Rule syntax.** A selector character that ends a variable in a rule's variable list
   (`02-grammar.md#variable-list`), such as `|` or whitespace, is written as a JSONPath
   escape (`['a|b']`). In an action argument such as `ctl:ruleRemoveTargetById`,
   rule authors SHOULD use the member-name shorthand (`JSON:$.user.bio`) for keys made of
   letters, digits and `_`, because single quotes delimit action values.
5. **Logging.** `MATCHED_VAR_NAME` for a match in either collection is the collection
   name, `:`, and the member's Normalized Path (`JSON:$['user']['name']`). Escapes inside
   a Normalized Path (`\'`, `\\`, `\uXXXX`) appear in names and logs only, never in a
   value an operator inspects.
6. **Relation to `ARGS`.** JSON values continue to fill `ARGS` and `ARGS_NAMES` under the
   engine's names (ADR-0020). `JSON` and `JSON_NAMES` are another view of the same
   values: they do not count a second time against `SecArgumentsLimit`, and
   `ARGS_COMBINED_SIZE` does not include them. Removing JSON values from `ARGS` needs its
   own Divergence ADR, once OWASP CRS targets `JSON`.
7. **Scope and status.** Both collections are Extended and cover the request body only.
   XML keeps the `XML` collection, and no `XML_ARGS` is added. An engine that implements
   one of the two collections implements both, with decisions 1 to 5.

## Options considered

- Standardise the JSON names inside `ARGS`: every scheme examined in ADR-0020 adds text
  that rules inspect, is ambiguous, or makes regular expressions hard; rejected there.
- Name the collection `JSON_ARGS`: it would read as part of `ARGS`, while `XML` already
  sets the pattern of one collection per structured body format; rejected.
- JSON Pointer (RFC 6901) for names and selectors (`/user/roles/0`): unambiguous, but it
  has no wildcard and no descendant step, so a key at any depth again needs a regular
  expression; rejected.
- The full RFC 9535 grammar: filter expressions and function extensions are a programming
  language inside a selector, costly to implement in C and hard to keep identical across
  three engines. The subset covers exclusions and targets; rejected.
- A selected object or array yields every scalar below it: convenient, but it gives `$`
  and `$..*` different meanings from RFC 9535; rejected. `..*` states the intent.
- Case-insensitive selectors, as for `ARGS`: `Role` and `role` are different JSON keys,
  and an exclusion for one would silently cover the other; rejected.
- `JSON_NAMES` values as Normalized Paths (`$['user']['role']`): every inspected value
  would carry `$`, `'` and `[`, which the SQL injection rules count; rejected. The path
  stays in the member name.
- Take JSON values out of `ARGS` now: every ruleset that has not added `JSON` would stop
  inspecting JSON bodies; deferred (decision 6).

## Consequences

- For ModSecurity v2, libmodsecurity v3 and Coraza: two new collections. Because the
  subset has no filters, a selector can be compiled into a matcher over Normalized Paths.
  An engine can then keep the list of (path, value) members it already builds for `ARGS`
  instead of the parsed tree, and needs no JSONPath library. Each engine must reject
  selectors outside the subset at load.
- For OWASP CRS: rules can add `JSON_NAMES|JSON` next to `ARGS_NAMES|ARGS`. On engines
  that do not implement them, the `?` prefix (ADR-0040) keeps the configuration loading.
  `JSON_NAMES` holds only the bytes of the client's keys, so the 930120 false positives
  caused by the `json.` prefix do not occur there. Until JSON leaves `ARGS`, a rule that
  targets both collections sees each JSON value twice.
- For rule authors: exclusions and targets name a JSON value the same way on every engine
  (`!JSON:$.user.bio`, `JSON:$..role`). `$['a.b']` and `$['a']['b']` are different
  members.
- For log consumers: `MATCHED_VAR_NAME` names the exact JSON node.

## Tests

None yet. Engine-tier tests would be added with the spec text and would `requires:` the
`JSON` anchor.

## References

- RFC 9535 (JSONPath), §2.7 Normalized Paths; RFC 8259 (JSON)
- ADR-0020, ADR-0040
- `spec/05-variables.md#xml`, `spec/05-variables.md#args-names`,
  `spec/09-body-processors.md#json`
- OWASP CRS issues 4810 and 4871 (coreruleset/coreruleset): rule 930120 false positives
  on JSON argument names
