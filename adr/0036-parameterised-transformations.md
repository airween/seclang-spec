# ADR-0036: Parameterised transformations, defined by name

- **Status:** accepted
- **Date:** 2026-11-10
- **Accepted:** 2026-11-11
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween, @franbuehler, @theseion
- **Category:** Extension

## Context

A transformation is a fixed function of its input: `t:NAME` takes no argument
(`08-actions.md#t`, `07-transformations.md`), and none of the three engines can carry one.

- ModSecurity v2 (v2.9.15): a transformation is `fn_tfn_execute_t` in `apache2/re.h`,
  which takes the pool and the input bytes only; `msre_action_t_validate` in
  `apache2/re_actions.c` resolves the action value as a name
  (`msre_engine_tfn_resolve`, "Invalid transformation function").
- libmodsecurity v3 (v3.0.17): the lexer has one token per transformation name
  (`src/parser/seclang-scanner.ll`, `ACTION_TRANSFORMATION_CMD_LINE (?i:t:cmdLine)` and
  its siblings); `Transformation::instantiate` in
  `src/actions/transformations/transformation.cc` maps the name to a class, and
  `Transformation::transform` (`transformation.h`) takes the value and the transaction.
- Coraza (v3.8.1): `plugintypes.Transformation` is `func(input string) (string, bool,
  error)` (`experimental/plugins/plugintypes/transformation.go`); `tFn.Init` in
  `internal/actions/t.go` looks the name up in the process-wide registry of
  `internal/transformations/transformations.go` (`GetTransformation`, `Register`).

All three key the transformation cache on the names in the chain: v2 builds `tfnskey` from
the `t` action values in `msre_rule_process_normal` (`apache2/re.c`), and Coraza derives
`transformationsID` from `transformationID(currentID, name)` in
`internal/corazawaf/rule.go`.

Any variation of a transformation's behaviour therefore has to be a new transformation.
`cmdLine` (`07-transformations.md#cmdline`) always deletes `\ " ' ^`, always splits on
space `, ; HT CR LF` and always lower-cases. A rule author who wants to keep `^` (an escape
character only in cmd.exe) or treat VT and FF as separators cannot. `removeComments` and
the whitespace set of `compressWhitespace` have the same problem.

## Decision

A new directive defines a named variant of a built-in transformation:

    SecTransformationVariant NAME BASE "PARAM=VALUE[;PARAM=VALUE...]"

- `NAME` is an identifier (`01-lexical.md#name-matching`). It MUST NOT be the name of a
  built-in transformation, nor of a variant defined earlier. Either case MUST be a
  configuration error.
- `BASE` MUST be a transformation whose entry in `07-transformations.md` lists
  **Parameters**. Any other base, an unknown parameter, or an invalid value MUST be a
  configuration error.
- A parameter that is not given keeps its default. The defaults are the transformation's
  Core behaviour, so a variant with no parameters behaves exactly like `BASE`.
- Rules use the variant like any transformation, `t:NAME`, after the directive that
  defines it. The `t:` grammar does not change.
- Byte sets are written the way `@validateByteRange` writes them
  (`06-operators.md#validatebyterange`): decimal bytes and `LOW-HIGH` ranges, separated
  by commas.

The first base that takes parameters is `cmdLine`:

| Parameter | Value | Default |
|---|---|---|
| `delete` | byte set | `34,39,92,94` (`" ' \ ^`) |
| `separators` | byte set | `9,10,13,32,44,59` |
| `joinBefore` | byte set: a separator run followed by one of these bytes is dropped | `40,47` (`( /`) |
| `lowercase` | `on` or `off` | `on` |

The directive and the Parameters field are Extended, as a new section of
`07-transformations.md` that profiles name in `requires:`.

## Options considered

- **Inline parameters, `t:cmdLine(delete=...)`.** Everything stays inside the rule. The
  value would sit inside an action value, so writing `'` or `,` would need quoting inside
  quoting (`'` is one of the bytes `cmdLine` deletes). Every engine's action lexer would
  change, v3's fixed token per name included. Every cache keyed by name would have to key
  on the parameters too. Rejected.
- **A fixed variant per need, e.g. `t:cmdLineUnix`.** No new grammar, but every variant
  costs an ADR and a spec entry, and authors still cannot tune them. Rejected.
- **Named variants defined by a directive (chosen).** Leaves `t:` alone, so the name is
  still a valid cache key. The parameters are parsed once, at configuration time. An
  engine without the feature fails at the directive (an unknown directive is a
  configuration error), which gives one clear error, and not at every rule that uses the
  variant.

## Consequences

- For all engines: one new directive, a registry of variants at configuration time, and
  a parameterised implementation of `cmdLine`. The built-in `cmdLine` is the variant with
  the defaults, so the Core tests are unchanged.
- For ModSecurity v2: `msre_engine_tfn_resolve` looks up the variant registry too, and
  the `tfnskey` cache needs no change because the variant's name is unique in a
  configuration.
- For libmodsecurity v3: `t:` followed by a name outside the fixed token list needs a
  lexer rule, and `Transformation::instantiate` a lookup in the variant registry.
- For Coraza: the registry in `internal/transformations` is process-wide, while variants
  belong to one WAF's configuration, so they need a per-WAF registry that `tFn.Init`
  consults first; `transformationID` needs no change.
- For rule authors: OWASP CRS cannot use variants until all three engines support the
  feature; a ruleset uses them only behind `requires:`.
- For the test data: the unit-tier case shape gains an optional `params` object, a
  change to the contract in `tests/README.md` that the three adapters and
  `seclang-check` follow together.
- For the formal model: `Transformations.lean` gives `cmdLine` a parameter record, and
  the existing guards check the defaults.

## Tests

None yet. Proposed with the spec text: a unit-tier file of `cmdLine` cases with `params`,
and an engine-tier profile of the configuration errors (shadowing a built-in, redefining a
variant, an unknown parameter, a bad byte set, a base without parameters).

## References

- `07-transformations.md#cmdline`
- `06-operators.md#validatebyterange`
