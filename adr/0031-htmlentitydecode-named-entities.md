# ADR-0031: `htmlEntityDecode` decodes the ASCII named entities of the WHATWG table

- **Status:** accepted
- **Date:** 2026-11-09
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

`spec/07-transformations.md#htmlentitydecode` is Core and named five entities, `&quot;
&amp; &lt; &gt; &nbsp;`, leaving every other named reference as is. That was what
ModSecurity implemented until GHSA-cxqf-vgrr-xxrv showed that a reference outside the five,
such as `javascript&colon;`, survives the transformation and bypasses rules that match
`javascript:`. Both ModSecurity branches fixed it in their September 2026 releases:

- ModSecurity v2.9.15 (`apache2/msc_util.c`, `msc_html_named_entities`) and libmodsecurity
  v3.0.17 (`src/actions/transformations/html_entity_decode.cc`, `named_entities`) carry the
  same 44-entry table, generated from `https://html.spec.whatwg.org/entities.json`: every
  entity that is one code point up to U+007F, plus `nbsp` and `shy`. The name is the whole
  run of letters and digits after `&`, compared case-insensitively; the output is one byte.
  Earlier releases compared only a prefix (`&ltest;` yielded `<`; v3.0.16 measured with the
  reference adapter).
- Coraza 3.8.1 (`internal/transformations/html_entity_decode.go`, `html.UnescapeString`)
  decodes every HTML5 entity, emits UTF-8 (`&nbsp;` is `C2 A0`, `&shy;`
  is `C2 AD`) and decodes the legacy forms without `;`, so `&ltest;` yields `<est;`.

The libmodsecurity reference adapter showed v3.0.17 decoding `&excl;` to `!` and `&shy;` to
the byte `AD`, against a spec that said both stay as they are.

## Decision

A named reference whose whole name, compared case-insensitively, is in the 44-entry table
MUST decode to the table's byte. Any other named reference, including one whose name only
begins with a listed name, is not specified. Normative text and the table:
`spec/07-transformations.md#htmlentitydecode`.

## Options considered

- Keep the five entities: both ModSecurity releases and Coraza now decode more, so all
  three would be non-conformant, and the spec would require the bypass the fix closed;
  rejected.
- The 44-entry table, other references unspecified (chosen): both ModSecurity releases
  conform exactly; Coraza diverges on the `nbsp` and `shy` bytes (`compat/known-gaps.md`)
  and may keep decoding more.
- Every HTML5 entity (Coraza): non-ASCII entities need a byte encoding the specification
  does not have (it operates on bytes, `spec/00-conventions.md`), and both ModSecurity
  releases would be non-conformant; rejected.
- Case-sensitive names as WHATWG spells them: matches browsers, but both ModSecurity
  releases compare case-insensitively and `&LPAR;` would then be unspecified
  rather than `(`; rejected in favour of the stricter rule two engines and the model share.

## Consequences

- For ModSecurity: v2.9.15 and v3.0.17 conform; earlier releases do not.
- For Coraza: `&shy;` yields `C2 AD` instead of `AD` (`compat/known-gaps.md`).
- For rule authors: `t:htmlEntityDecode` now normalises punctuation written as entities
  (`&colon;`, `&lpar;`), so a rule matching `javascript:` also sees `javascript&colon;`.

## Tests

- `tests/unit/transformations/htmlEntityDecode-extra.json`
- `tests/unit/transformations/htmlEntityDecode.json`

## References

- `spec/07-transformations.md#htmlentitydecode`
- GHSA-cxqf-vgrr-xxrv (owasp-modsecurity/ModSecurity)
- `https://html.spec.whatwg.org/multipage/named-characters.html`
