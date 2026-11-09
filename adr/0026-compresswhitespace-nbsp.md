# ADR-0026: `compressWhitespace` treats the byte 0xA0 as whitespace

- **Status:** accepted
- **Date:** 2026-10-08
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

`t:compressWhitespace` replaces runs of whitespace with one space. The engines disagree on
the non-breaking space byte 0xA0:

- ModSecurity v2 (`apache2/re_tfns.c`, `msre_fn_compressWhitespace_execute`): `isspace`
  or `NBSP` (0xA0), byte by byte.
- libmodsecurity v3.0.16 (`src/actions/transformations/compress_whitespace.cc`):
  `isspace` only; 0xA0 is an ordinary byte. Unchanged in v3.0.17 (rechecked 2026-11-09
  with the reference adapter).
- Coraza 3.8.1 (`internal/transformations/compress_whitespace.go`): decodes runes; a bare
  0xA0 byte (`rawNBSP`) and the UTF-8 sequences `C2 A0` and `C2 85` are whitespace, while
  an 0xA0 inside another valid sequence (`à`, `C3 A0`) is kept.

`t:removeWhitespace`, a Core transformation, already specifies 0xA0 as whitespace at the
byte level (`spec/07-transformations.md#removewhitespace`), and the specification operates
on bytes throughout (`spec/00-conventions.md`). The Lean model of the chapter
(`formal/`) forced the choice: the prose listed only the `isspace` set and no test covered
the byte.

## Decision

For `compressWhitespace` the byte 0xA0 MUST be treated as whitespace, exactly as for
`removeWhitespace`. The rule is byte-level: an 0xA0 inside a multi-byte UTF-8 sequence is
whitespace too. Normative text: `spec/07-transformations.md#compresswhitespace`.

## Options considered

- `isspace` only (v3): keeps v3 conformant, but makes the two whitespace transformations
  inconsistent and both v2 and Coraza non-conformant on the bare byte; rejected.
- Byte-level 0xA0 (chosen): consistent with `removeWhitespace`, matches v2 and Coraza on
  the bare byte, one engine to fix.
- UTF-8-aware (Coraza): the specification has no notion of character encoding in
  transformations; rejected.

## Consequences

- For libmodsecurity v3: compress 0xA0 (`compat/known-gaps.md`).
- For Coraza: conformant on bare bytes; its handling of 0xA0 inside valid UTF-8 differs
  from the byte-level rule (no corpus case exercises it).
- For rule authors: a value containing `à` (`C3 A0`) becomes `C3 20` after
  `compressWhitespace`, as it already loses the byte under `removeWhitespace`.

## Tests

- `tests/unit/transformations/compressWhitespace-extra.json`

## References

- `spec/07-transformations.md#compresswhitespace`
- `spec/07-transformations.md#removewhitespace`
- `compat/known-gaps.md`
