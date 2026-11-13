# ADR-0042: `unicodeNormalizeNFKC` applies Unicode NFKC normalisation

- **Status:** proposed
- **Date:** 2026-11-12
- **Deciders:** @fzipi
- **Category:** Extension

## Context

Unicode gives many characters a compatibility equivalent: fullwidth `Ａ` (U+FF21) is `A`,
superscript `²` is `2`, the ligature `ﬁ` is `fi`, mathematical bold `𝐬` is `s`. NFKC,
defined in UAX #15, replaces each character with that equivalent and then composes the
result. Many application stacks apply it to input before use: Python
`unicodedata.normalize`, .NET `String.Normalize`, Java `java.text.Normalizer`, ICU.
A rule that should see the same string as such a backend has no way to ask for it.

No surveyed engine has a Unicode normalisation transformation: ModSecurity v2 (v2.9.15)
and libmodsecurity v3 (v3.0.17) register none in `msre_engine_register_default_tfns`
and `Transformation::instantiate`, and Coraza (v3.8.1) none in
`internal/transformations/transformations.go`.

What exists today does not cover it:

- `07-transformations.md#utf8tounicode` followed by `07-transformations.md#urldecodeuni`
  maps code points through the `SecUnicodeMapFile` table (`04-directives.md#secunicodemapfile`,
  Extended, not in Coraza). That table is a code-page best fit, not Unicode
  normalisation. It covers only `%uXXXX`, so only the Basic Multilingual Plane, and
  yields one byte per code point. Without the table, only `%uFF01` to `%uFF5E` map to
  ASCII.
- `06-operators.md#validateutf8encoding` matches ill-formed UTF-8. Every character NFKC
  changes is well-formed, so validation and normalisation do not overlap. OWASP CRS
  enables it by default since v4.28.0 (rule 920250, on `REQUEST_FILENAME`, `ARGS` and
  `ARGS_NAMES`). There, a value that reaches the transformation is almost always
  well-formed; on any other variable it may not be.

## Decision

A new Extended transformation, `t:unicodeNormalizeNFKC`:

- **Well-formed UTF-8.** The value MUST be read as UTF-8 (RFC 3629) and replaced with
  its Normalization Form KC, as UAX #15 defines it.
- **Ill-formed bytes.** A byte that does not belong to a well-formed sequence MUST be
  copied unchanged, and MUST act as a boundary: the well-formed runs on each side are
  normalised separately, and nothing composes across it. It MUST NOT be replaced with
  U+FFFD or dropped. This matches what `07-transformations.md#utf8tounicode` does with
  ill-formed bytes.
- **Unicode version.** An engine MUST use Unicode 15.0 or later. The Unicode
  Normalization Stability Policy keeps the result for every character assigned in 15.0
  the same in later versions. A code point unassigned in the engine's version is left
  unchanged, so results on characters assigned after 15.0 may differ between engines.
- **Length.** The output MAY be longer than the input: U+FDFA, 3 bytes, becomes 33. An
  engine MUST NOT assume the output fits in the input's buffer.
- **Idempotence.** Applying the transformation twice gives the same result as once.
- **Scope.** NFKC does not fold case and does not remove default-ignorable characters.
  `07-transformations.md#lowercase` stays ASCII-only, so a rule that wants both writes
  `t:unicodeNormalizeNFKC,t:lowercase`. The transformation belongs after the decoding
  transformations (`urlDecodeUni`, `htmlEntityDecode`, `jsDecode`, ...) that produce
  the UTF-8 bytes it reads.

Expected results, as bytes in hexadecimal:

| Input | Input bytes | Output bytes | Output |
|---|---|---|---|
| `ＡＢＣ` (U+FF21 U+FF22 U+FF23) | `ef bc a1 ef bc a2 ef bc a3` | `41 42 43` | `ABC` |
| `（` (U+FF08) | `ef bc 88` | `28` | `(` |
| ideographic space (U+3000) | `e3 80 80` | `20` | space |
| no-break space (U+00A0) | `c2 a0` | `20` | space |
| `²` (U+00B2) | `c2 b2` | `32` | `2` |
| `½` (U+00BD) | `c2 bd` | `31 e2 81 84 32` | `1⁄2` |
| `ﬁ` (U+FB01) | `ef ac 81` | `66 69` | `fi` |
| `𝐬` (U+1D42C) | `f0 9d 90 ac` | `73` | `s` |
| `ſ` (U+017F) | `c5 bf` | `73` | `s` |
| `Ⓐ` (U+24B6) | `e2 92 b6` | `41` | `A` |
| `①` (U+2460) | `e2 91 a0` | `31` | `1` |
| Kelvin sign (U+212A) | `e2 84 aa` | `4b` | `K` |
| Ohm sign (U+2126) | `e2 84 a6` | `ce a9` | `Ω` (U+03A9) |
| `e` + combining acute (U+0065 U+0301) | `65 cc 81` | `c3 a9` | `é` (U+00E9) |
| `é` (U+00E9) | `c3 a9` | `c3 a9` | unchanged |
| Hangul jamo (U+1100 U+1161) | `e1 84 80 e1 85 a1` | `ea b0 80` | `가` (U+AC00) |
| halfwidth `ｶﾞ` (U+FF76 U+FF9E) | `ef bd b6 ef be 9e` | `e3 82 ac` | `ガ` (U+30AC) |
| U+FDFA | `ef b7 ba` | 33 bytes | `صلى الله عليه وسلم` |
| soft hyphen (U+00AD) | `c2 ad` | `c2 ad` | unchanged |
| zero width space (U+200B) | `e2 80 8b` | `e2 80 8b` | unchanged |
| ASCII `Hello` | `48 65 6c 6c 6f` | `48 65 6c 6c 6f` | unchanged |
| ill-formed `ff` between `ＡＢ` | `ef bc a1 ff ef bc a2` | `41 ff 42` | ill-formed byte kept |
| `e`, ill-formed `80`, combining acute | `65 80 cc 81` | `65 80 cc 81` | no composition across `80` |

## Options considered

- **One transformation, NFKC only (chosen).** NFKC is the form that maps compatibility
  characters to the ones a backend compares against. A rule rarely needs the other
  three forms: NFC and NFD leave compatibility characters as they are, and NFKD leaves
  combining marks apart, which `@rx` and `@pm` would then see as separate characters.
  Each can be added by a later ADR under the same naming pattern if a rule needs it.
- **All four forms (`unicodeNormalizeNFC`, `NFD`, `NFKC`, `NFKD`).** Same cost to
  implement with a library, but three entries to specify and test that no rule uses yet.
  Not chosen.
- **`NFKC_Casefold` (Unicode's `NFKC_CF` mapping).** Also folds case and removes
  default-ignorable characters such as U+00AD and U+200B. It is not what the backends
  above apply, and it mixes Unicode case folding into a language whose `lowercase` is
  ASCII-only. Left for a separate transformation if a rule needs it.
- **Extend the `SecUnicodeMapFile` table.** Code-page dependent, one byte per code
  point, limited to the Basic Multilingual Plane, and not in Coraza. Rejected.
- **An operator that normalises before comparing.** Doesn't compose with other
  transformations and would be needed for every operator. Rejected.
- **Replace ill-formed bytes with U+FFFD.** It is what many decoders do, but it would
  hide the original bytes from later transformations and operators. Rejected.

## Consequences

- For ModSecurity v2 and libmodsecurity v3: a new transformation backed by a
  normalisation library (ICU's `unorm2_getNFKCInstance`, or utf8proc's `utf8proc_NFKC`).
  Both libraries reject ill-formed input, so the engine has to split the value into
  well-formed runs and ill-formed bytes itself. v2 cannot transform in place, since the
  output may grow.
- For Coraza: `golang.org/x/text/unicode/norm` (`norm.NFKC`), already an indirect
  dependency in `go.mod`. How it treats ill-formed bytes needs checking against the
  boundary rule above.
- For rule authors: a ruleset uses the transformation only behind `requires:` until all
  three engines have it. An ASCII-only value is unchanged, so on mostly-ASCII traffic
  the cost is a scan of the value.
- For the formal model: NFKC needs the Unicode decomposition and composition tables, so
  `Transformations.lean` would carry a generated table, or check only the cases in the
  unit tier.

## Tests

None yet. Proposed with the spec text: a unit-tier file for the transformation with the
rows of the table above, all using characters assigned in Unicode 15.0 or earlier.

## References

- UAX #15, Unicode Normalization Forms: <https://www.unicode.org/reports/tr15/>
- Unicode Normalization Stability Policy:
  <https://www.unicode.org/policies/stability_policy.html>
- `07-transformations.md#utf8tounicode`, `07-transformations.md#urldecodeuni`,
  `06-operators.md#validateutf8encoding`, `04-directives.md#secunicodemapfile`
