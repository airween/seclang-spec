# ADR-0043: `evalDepth` evaluates a chain once per match of its starter

- **Status:** proposed
- **Date:** 2026-11-12
- **Deciders:** @fzipi
- **Category:** Extension

## Context

A chain is evaluated member by member (`03-processing-model.md#chains`). All three
engines evaluate the chain starter against every target first, and the next member once
afterwards. Each match overwrites `MATCHED_VAR`, `MATCHED_VAR_NAME` and the `capture`
groups `TX:0` to `TX:9` (`08-actions.md#capture`), so the members see only the context of
the starter's last match:

```apache
SecRule ARGS "@rx (attack\d+)" "id:1,phase:2,deny,capture,chain"
    SecRule TX:1 "@rx attack2" "t:none"
```

With `a=attack2&b=attack1` the member sees `TX:1=attack1` and the chain does not match,
although `a` alone satisfies it. With the arguments the other way round, it matches. A
member cannot test a property of the same target the starter matched, and `%{MATCHED_VAR}`
in `msg` or `logdata` names the last match, not the one that satisfied the chain.

- ModSecurity v2 (v2.9.15) and libmodsecurity v3 (v3.0.17): evaluate as above. Neither
  has an action to change it.
- Coraza (v3.8.1): evaluates as above. Coraza issue #1608 asks for depth-first evaluation,
  and Coraza PR #1744 adds it as the flow action `evalDepth` on the chain starter, not yet
  merged.

OWASP CRS is written against the current behaviour, so the default can't change.

## Decision

A new Extended action, `evalDepth`, with no argument:

1. **Placement.** `evalDepth` MAY appear only on the starter of a chain of `SecRule`s. On
   a chain member, on a rule without `chain`, or on a `SecAction`, it MUST be a
   configuration error.
2. **Without `evalDepth`**, chains are evaluated as today.
3. **With `evalDepth`**, each match of the starter is a context: `MATCHED_VAR`,
   `MATCHED_VAR_NAME` and `TX:0` to `TX:9` as that match left them. A `TX:N` that the
   match did not set is absent in its context, not empty. Each target is a match, and
   each value that matches under `multiMatch` is one too. For each context, in the order
   the engine evaluated the targets, the engine MUST restore the context and then
   evaluate the remaining members. The chain matches at the first context for which all
   of them match. Later contexts are not tried.
4. **Nested chains.** A member that is followed by further members and matches more than
   one target makes its own contexts the same way, so every level is depth-first.
5. **What the match reports.** When the chain matches, `msg`, `logdata` and the log
   record MUST be expanded in the context of the path that matched: the starter's match
   and the members' matches below it. When more than one path would match, which one is
   reported is unspecified, since target order is engine-defined. ADR-0041 leaves the
   logging of chains open; this decision covers only chains with `evalDepth`.
6. **Side effects.** The starter's non-disruptive actions run once per match, as today. A
   member's run every time it matches, including in a context whose remaining members
   later fail. So a member's `setvar` can run once per context.
   `MATCHED_VARS` and `MATCHED_VARS_NAMES` keep an entry for every match attempted. When
   no path matches, the transaction keeps the state of the last attempt.
7. **Bound.** A chain of n members over a collection of m targets can evaluate the
   members up to m^(n−1) times. An engine MUST bound the operator evaluations of one
   chain under `evalDepth`; Coraza's limit is 10,000. When the bound is reached, the
   engine MUST evaluate the remaining members once, as without `evalDepth`, with the
   current context, and MUST log a warning.

## Options considered

- **A per-rule action on the chain starter (chosen).** The rule that needs per-match
  context opts in, and no other chain changes. An engine without the action fails at
  configuration time, so a ruleset declares it in `requires:`.
- **A directive that switches every chain.** Changes the meaning of every loaded
  ruleset at once, CRS included. Rejected.
- **A per-transaction `ctl`.** A `ctl` runs only after its rule matches, so it cannot
  change its own chain; it would have to be set by an earlier rule and then switch every
  later chain in the transaction, with the same problem as the directive. Rejected.
- **A separate directive, `SecRuleDepthFirst`.** Duplicates `SecRule` for one flag, and
  the members are still plain `SecRule`s. Rejected.
- **Depth-first by re-evaluating the starter.** Re-runs the starter's operator for every
  attempt. Saving each match's context costs one snapshot of about twelve strings per
  match instead, and each operator still runs once per target. This is the mechanism
  decision 3 describes.
- **No bound.** An attacker who controls the number of targets controls the work, which
  grows as a power of it. Rejected.

## Consequences

- For ModSecurity v2 and libmodsecurity v3: a new action, a per-match snapshot of the
  match variables and captures, and the bounded depth-first loop. Rules without the
  action keep the same code path.
- For Coraza: Coraza PR #1744 implements decisions 1 to 7. This ADR needs its merge, and
  the action reported in the matrix.
- For rule authors: chains that test the starter's own target, such as
  `ARGS "@rx (…)" … chain` followed by `TX:1 …`, give the same answer whatever the order
  of the arguments. A ruleset uses `evalDepth` only behind `requires:` until all three
  engines have it. It must not be the only blocking control where an attacker can add
  enough targets to reach the bound.
- For the test data: an engine profile that `requires:` the action.

## Tests

None yet. Proposed with the spec text: an engine profile with the example above in both
argument orders, a nested chain, a member's `setvar` in a failed context, and the
configuration errors of decision 1.

## References

- `03-processing-model.md#chains`, `08-actions.md#capture`, `08-actions.md#multimatch`
- Coraza issue #1608: <https://github.com/corazawaf/coraza/issues/1608>
- Coraza PR #1744: <https://github.com/corazawaf/coraza/pull/1744>
