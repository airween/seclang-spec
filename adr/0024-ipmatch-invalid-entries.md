# ADR-0024: Unparsable `@ipMatch` entries are configuration errors

- **Status:** proposed
- **Date:** 2026-10-07
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

`@ipMatch LIST` takes addresses and CIDR prefixes. The engines disagree on an entry that
cannot be parsed, such as `10.0.0.0/100`: ModSecurity v2 (`apache2/re_operators.c`,
`msre_op_ipmatch_param_init` returns an error from `TreeAddIP`) and libmodsecurity v3
(`src/operators/ip_match.cc`, `init` fails and the rule is rejected) refuse to load the
rule; Coraza 3.8.1 (`internal/operators/ip_match.go`) skips the entry with `continue` and
loads the rule with the remaining ones. The SecRules Test Set carries a case asserting a
non-match for `10.0.0.0/100`, which only Coraza satisfies. The libmodsecurity reference
adapter surfaced the disagreement.

## Decision

Every entry of an `@ipMatch` list MUST be a valid address or prefix; an entry that cannot
be parsed is a configuration error. Normative text: `spec/06-operators.md#ipmatch`. The
corpus case is excluded on import (`tools/import_sts.py` `EXCLUDED_CASES`).

Overlapping and repeated entries are valid and are not an error: the list matches when any
entry does, so an entry covered by another changes nothing. An engine MAY warn when one
entry lies entirely inside another, since that can be a mistyped prefix.

## Options considered

- Skip unparsable entries (Coraza): a typo in a blocklist silently narrows it; rejected.
- Configuration error (chosen): two engines agree, and a list that is partly unusable
  fails loudly where the operator is written.
- Overlapping entries as configuration errors: an overlap is only sometimes a typo, so
  correct lists (broad range plus a host inside it, merged feeds, generated lists with
  duplicates) would be rejected, and the typos that narrow a list overlap nothing; rejected
  in favour of an optional warning. Coraza 3.8.1 loads and matches such a list.

## Consequences

- For Coraza: return an error from the `@ipMatch` constructor on a `ParseCIDR` failure
  (`compat/known-gaps.md`).
- For rule authors: an invalid entry stops the configuration from loading, as it does
  today on both ModSecurity branches.

## Tests

- `tests/engine/operators/ipmatch-invalid-entry.yaml`
- `tests/engine/operators/ipmatch-overlap.yaml`
- `tests/unit/operators/ipMatch.json`

## References

- `spec/06-operators.md#ipmatch`
- `adapters/libmodsecurity/README.md`
