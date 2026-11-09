# 07. Transformations

A transformation rewrites a variable's value before the operator sees it; they apply in
`t:` order, after those inherited from `SecDefaultAction` unless `t:none` resets the
list (`02-grammar.md#action-list`). The index lists every transformation name known to
any surveyed engine with its status (`00-conventions.md`); aliases appear under their
canonical name (ADR-0004).

Unit-tier cases live in `tests/unit/transformations/`, imported from the SecRules Test
Set by `tools/import_sts.py` (`tests/README.md`), except `base64Decode.json`, which
encodes the Phase 1 decision on malformed input. The Lean definitions in
`formal/SecLang/Transformations.lean` are the executable reference for the behaviour this
chapter defines (`formal/README.md`); where the text
leaves input unspecified, as for malformed `base64Decode` input, the model's choice is
not normative.

## Index

| Transformation | Status | v2 | v3 | Coraza | Purpose |
|---|---|---|---|---|---|
| [base64Decode](#base64decode) | Core | yes | yes | yes | Decode standard Base64 |
| [base64DecodeExt](#base64decodeext) | Extended | yes | yes | yes | Decode Base64 skipping invalid characters |
| [base64Encode](#base64encode) | Extended | yes | yes | yes | Encode as Base64 |
| [cmdLine](#cmdline) | Core | yes | yes | yes | Normalise shell command lines |
| [compressWhitespace](#compresswhitespace) | Core | yes | yes | yes | Collapse whitespace runs to one space |
| [cssDecode](#cssdecode) | Core | yes | yes | yes | Decode CSS escapes |
| [escapeSeqDecode](#escapeseqdecode) | Core | yes | yes | yes | Decode ANSI C escapes |
| [hexDecode](#hexdecode) | Extended | yes | yes | yes | Decode hexadecimal |
| [hexEncode](#hexencode) | Core | yes | yes | yes | Encode as hexadecimal |
| [htmlEntityDecode](#htmlentitydecode) | Core | yes | yes | yes | Decode HTML entities |
| [jsDecode](#jsdecode) | Core | yes | yes | yes | Decode JavaScript escapes |
| [length](#length) | Core | yes | yes | yes | Replace with the byte length |
| [lowercase](#lowercase) | Core | yes | yes | yes | ASCII lower case |
| [md5](#md5) | Extended | yes | yes | yes | MD5 digest (raw bytes) |
| [none](#none) | Core | yes | yes | yes | Discard inherited transformations |
| [normalisePath](#normalisepath) | Core | yes | yes | yes | Resolve . and .. and duplicate slashes |
| [normalisePathWin](#normalisepathwin) | Core | yes | yes | yes | As normalisePath, also converting backslashes |
| [normalizePath](#normalisepath) | alias of [normalisePath](#normalisepath) | yes | yes | yes | Alias of normalisePath |
| [normalizePathWin](#normalisepathwin) | alias of [normalisePathWin](#normalisepathwin) | yes | yes | yes | Alias of normalisePathWin |
| [parityEven7bit](#parityeven7bit) | Extended | yes | yes | - | Set the parity bit (even) |
| [parityOdd7bit](#parityodd7bit) | Extended | yes | yes | - | Set the parity bit (odd) |
| [parityZero7bit](#parityzero7bit) | Extended | yes | yes | - | Clear the eighth bit |
| [removeComments](#removecomments) | Extended | yes | yes | yes | Remove C, SQL and shell comments |
| [removeCommentsChar](#removecommentschar) | Core | yes | yes | yes | Remove comment delimiters only |
| [removeNulls](#removenulls) | Core | yes | yes | yes | Remove NUL bytes |
| [removeWhitespace](#removewhitespace) | Core | yes | yes | yes | Remove all whitespace |
| [replaceComments](#replacecomments) | Core | yes | yes | yes | Replace C-style comments with one space |
| [replaceNulls](#replacenulls) | Extended | yes | yes | yes | Replace NUL bytes with spaces |
| [sha1](#sha1) | Core | yes | yes | yes | SHA-1 digest (raw bytes) |
| [sqlHexDecode](#sqlhexdecode) | Extended | yes | yes | - | Decode SQL 0x hex literals |
| [trim](#trim) | Extended | yes | yes | yes | Strip leading and trailing whitespace |
| [trimLeft](#trimleft) | Extended | yes | yes | yes | Strip leading whitespace |
| [trimRight](#trimright) | Extended | yes | yes | yes | Strip trailing whitespace |
| [uppercase](#uppercase) | Core | - | yes | yes | ASCII upper case |
| [urlDecode](#urldecode) | Extended | yes | yes | yes | Decode %XX and + |
| [urlDecodeUni](#urldecodeuni) | Core | yes | yes | yes | Decode %XX, + and %uXXXX |
| [urlEncode](#urlencode) | Extended | yes | yes | yes | Percent-encode |
| [utf8toUnicode](#utf8tounicode) | Core | yes | yes | yes | Convert UTF-8 sequences to %uXXXX |

## Core transformations

A transformation returns the new value and whether it changed the input; the unit
cases record the latter as `ret`. All transformations operate on bytes; "whitespace" means
the ASCII characters space, tab, LF, VT, FF and CR unless a section says otherwise.

### base64Decode

**Status:** Core

**Syntax.** `t:base64Decode`

**Semantics.** Decodes the input as standard Base64 (RFC 4648 section 4, alphabet
`A-Z a-z 0-9 + /`, `=` padding). For a well-formed, correctly padded input the output is
the decoded bytes; decoded NUL bytes are preserved. The empty input produces the empty
output and reports no change. A NUL byte in the *input* terminates it: nothing after
the first NUL is decoded.

Behaviour on malformed input is **not specified** in this version; see the divergence
notes. Compare `base64DecodeExt`, which skips characters outside the alphabet.

**Divergence notes.** The engines disagree on malformed input, so the tests only cover
well-formed input until a Divergence ADR settles it:

- ModSecurity v2 (`apr_base64_decode`) and Coraza (`internal/transformations/
  base64decode.go`) decode up to the first byte outside the alphabet and discard the
  rest; Coraza additionally ignores `\r` and `\n`.
- libmodsecurity v3 (`src/utils/base64.cc`, mbedtls) rejects the whole input on any
  byte outside the alphabet, on a length that is not a multiple of four (missing
  padding) and on padding followed by data, leaving the value unchanged; it ignores
  `\n` and `\r\n`.

**Tests.** `tests/unit/transformations/base64Decode.json`

### cmdLine

**Status:** Core

**Syntax.** `t:cmdLine`

**Semantics.** Normalises a command line as the ModSecurity reference manual defines:
deletes `\`, `"`, `'`, `^`; replaces each run of the separators space, `,`, `;`, HT, CR
and LF with one space and drops that space when `/` or `(` follows; lower-cases ASCII
letters. VT and FF are ordinary bytes.

**Divergence notes.** ModSecurity v2 (`re_tfns.c`) processes the value as a C string and
stops at the first NUL byte; libmodsecurity v3 and Coraza process every byte.

**Tests.** `tests/unit/transformations/cmdLine.json`

### compressWhitespace

**Status:** Core

**Syntax.** `t:compressWhitespace`

**Semantics.** Replaces every run of one or more whitespace bytes (space, tab, LF, VT,
FF, CR, and the non-breaking space byte 0xA0, as in `removeWhitespace`) with a single
space; NUL is not whitespace.

**Divergence notes.** Decided by ADR-0026. libmodsecurity v3 (`compress_whitespace.cc`,
`isspace`) does not treat 0xA0 as whitespace; ModSecurity v2 (`NBSP`) and Coraza
(`rawNBSP`) do (`compat/known-gaps.md`). Coraza decodes runes, so it also compresses the
UTF-8 sequences `C2 A0` and `C2 85` and keeps an 0xA0 inside another valid sequence.

**Tests.** `tests/unit/transformations/compressWhitespace.json`,
`tests/unit/transformations/compressWhitespace-extra.json`

### cssDecode

**Status:** Core

**Syntax.** `t:cssDecode`

**Semantics.** Decodes CSS 2.x escape sequences. A backslash followed by one to six
hexadecimal digits yields one byte: the value of the last two digits (of the single digit
for a one-digit escape), except that a full-width ASCII escape, `\ffXX`, `\0ffXX` or
`\00ffXX` with `XX` in `01`–`5e`, yields `XX + 0x20`, its ASCII counterpart. One
whitespace byte (space, HT, LF, VT, FF or CR) directly after the digits is consumed. A
backslash followed by a newline is removed, a backslash followed by any other byte
yields that byte, and a trailing backslash is removed.

**Divergence notes.** Two corpus inputs differ: ModSecurity emits the low byte of an
escape's code point (`\123` is `#`), Coraza 3.8.1 emits the UTF-8 encoding of the code
point and U+FFFD above U+FFFF (`compat/known-gaps.md`). The imported cases keep the
ModSecurity expectation. One corpus
case expected a space after `\` followed by a NUL byte to be dropped; no engine drops it
(only a hex escape consumes a following whitespace), so the file is hand-maintained and
the case corrected.

**Tests.** `tests/unit/transformations/cssDecode.json`

### escapeSeqDecode

**Status:** Core

**Syntax.** `t:escapeSeqDecode`

**Semantics.** Decodes ANSI C escape sequences: `\a \b \f \n \r \t \v \\ \? \' \"`,
octal `\ooo` (up to three digits) and hexadecimal `\xHH`. A backslash before any byte
that does not begin a recognised sequence is dropped and the byte kept (`\8` becomes
`8`, `\xag` becomes `xag`, a trailing `\x` becomes `x`); only a lone trailing `\` is kept
(ModSecurity v2 `apache2/msc_util.c`, libmodsecurity v3 `escape_seq_decode.cc`, Coraza
`escape_seq_decode.go`).

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/escapeSeqDecode.json`

### hexEncode

**Status:** Core

**Syntax.** `t:hexEncode`

**Semantics.** Replaces each byte with its two lowercase hexadecimal digits.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/hexEncode.json`

### htmlEntityDecode

**Status:** Core

**Syntax.** `t:htmlEntityDecode`

**Semantics.** Decodes `&#NNN;` and `&#xHH;` numeric references (the `;` optional) and
named references. A numeric reference yields one byte, the low 8 bits of the code point
(ModSecurity v2 `msc_util.c`, libmodsecurity v3 `html_entity_decode.cc`). A named
reference is `&`, the longest following run of ASCII letters and digits, and an optional
`;`. When the whole run, compared case-insensitively, is one of the names below, the
reference MUST decode to the byte listed (ADR-0031). The names are every WHATWG named
character reference that is one code point up to U+007F, plus `nbsp` and `shy`:

| Byte | Names |
|---|---|
| `09` | `tab` |
| `0A` | `newline` |
| `21` | `excl` |
| `22` | `quot` |
| `23` | `num` |
| `24` | `dollar` |
| `25` | `percnt` |
| `26` | `amp` |
| `27` | `apos` |
| `28` | `lpar` |
| `29` | `rpar` |
| `2A` | `ast`, `midast` |
| `2B` | `plus` |
| `2C` | `comma` |
| `2E` | `period` |
| `2F` | `sol` |
| `3A` | `colon` |
| `3B` | `semi` |
| `3C` | `lt` |
| `3D` | `equals` |
| `3E` | `gt` |
| `3F` | `quest` |
| `40` | `commat` |
| `5B` | `lbrack`, `lsqb` |
| `5C` | `bsol` |
| `5D` | `rbrack`, `rsqb` |
| `5E` | `hat` |
| `5F` | `lowbar`, `underbar` |
| `60` | `diacriticalgrave`, `grave` |
| `7B` | `lbrace`, `lcub` |
| `7C` | `verbar`, `vert`, `verticalline` |
| `7D` | `rbrace`, `rcub` |
| `A0` | `nbsp`, `nonbreakingspace` |
| `AD` | `shy` |

Any other named reference, including one whose run only begins with a listed name
(`&ltest;`), is **not specified**: an engine MAY leave it as is or decode it.

**Divergence notes.** ModSecurity v2.9.15 (`msc_util.c`, `msc_html_named_entities`) and
libmodsecurity v3.0.17 (`html_entity_decode.cc`, `named_entities`) implement the table above
as written and leave every other named reference as is. Earlier releases knew only `quot`,
`amp`, `lt`, `gt` and `nbsp` and compared a prefix, so `&ltest;` yielded `<` (v3.0.16
measured). Coraza 3.8.1 (`internal/transformations/html_entity_decode.go`,
`html.UnescapeString`) decodes every HTML5 named entity and emits UTF-8: `&nbsp;` yields `C2 A0`
instead of the byte `A0` and two imported cases fail there (`compat/known-gaps.md`),
`&shy;` yields `C2 AD`, and the legacy forms without `;` decode, so `&ltest;` yields
`<est;`.

**Tests.** `tests/unit/transformations/htmlEntityDecode.json`,
`tests/unit/transformations/htmlEntityDecode-extra.json`

### jsDecode

**Status:** Core

**Syntax.** `t:jsDecode`

**Semantics.** Decodes JavaScript escapes: `\uHHHH` (one byte, the low 8 bits of the
code point; full-width forms `\uFF01`–`\uFF5E` map to their ASCII counterparts),
`\xHH`, octal `\ooo` (up to three digits, two when three would exceed one byte), and
`\a \b \f \n \r \t \v`; a backslash before any other byte is removed.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/jsDecode.json`

### length

**Status:** Core

**Syntax.** `t:length`

**Semantics.** Replaces the value with its length in bytes as a decimal string.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/length.json`

### lowercase

**Status:** Core

**Syntax.** `t:lowercase`

**Semantics.** Converts ASCII letters `A`–`Z` to lower case; other bytes unchanged.

**Divergence notes.** Coraza 3.8.1 uses `strings.ToLower`, which also folds non-ASCII
letters in valid UTF-8 and replaces lone high bytes with U+FFFD; the Core cases are
ASCII-only.

**Tests.** `tests/unit/transformations/lowercase.json`

### none

**Status:** Core

**Syntax.** `t:none`

**Semantics.** Not a transformation of the value: it resets the rule's transformation
list to empty at the point where it appears, so only the `t:` actions after it apply.
Engines MUST accept it anywhere in the list. Since `SecDefaultAction` may not carry
transformations (ADR-0014), `t:none` at the start of a rule is a no-op; CRS puts it first
on every rule for clarity and for compatibility with engines that once allowed inherited
transformations.

**Divergence notes.** None known.

**Tests.** `tests/engine/actions/t-none.yaml`

### normalisePath

**Status:** Core

**Syntax.** `t:normalisePath`; alias `t:normalizePath` (ADR-0004).

**Semantics.** Resolves `.` and `..` segments, collapses repeated `/`, and removes a
trailing `/.`; never ascends above the leading `/`. Operates on the whole value, so apply
it to path variables, not to `REQUEST_URI` with a query string.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/normalisePath.json`

### normalisePathWin

**Status:** Core

**Syntax.** `t:normalisePathWin`; alias `t:normalizePathWin`.

**Semantics.** Converts `\` to `/`, then behaves as `normalisePath`.

**Divergence notes.** ModSecurity v2 (`normalize_path_inplace`) and libmodsecurity v3
(`normalise_path.cc`) convert a backslash only when it is the current or the next byte, so
a backslash reached while skipping a run of slashes is kept: `a//\b` yields `a\b`
(`compat/known-gaps.md`). Coraza converts every backslash first.

**Tests.** `tests/unit/transformations/normalisePathWin.json`,
`tests/unit/transformations/normalisePathWin-extra.json`

### removeCommentsChar

**Status:** Core

**Syntax.** `t:removeCommentsChar`

**Semantics.** Removes the comment delimiters `/*`, `*/`, `<!--`, `-->`, `--` and `#`
wherever they occur, leaving the text between them.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/removeCommentsChar.json`

### removeNulls

**Status:** Core

**Syntax.** `t:removeNulls`

**Semantics.** Removes every NUL byte.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/removeNulls.json`

### removeWhitespace

**Status:** Core

**Syntax.** `t:removeWhitespace`

**Semantics.** Removes every whitespace byte (space, tab, LF, VT, FF, CR) and the
non-breaking space byte 0xA0.

**Divergence notes.** Coraza 3.8.1 (`remove_whitespace.go`, `unicode.IsSpace` over
runes) removes the non-breaking space only in its UTF-8 form `C2 A0` and replaces lone
high bytes with U+FFFD; see `compat/known-gaps.md` for the affected corpus cases.

**Tests.** `tests/unit/transformations/removeWhitespace.json`

### replaceComments

**Status:** Core

**Syntax.** `t:replaceComments`

**Semantics.** Replaces each C-style comment `/* ... */` with one space; an unterminated
`/*` comments out the rest of the value. Does not touch `--` or `#` comments.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/replaceComments.json`

### sha1

**Status:** Core

**Syntax.** `t:sha1`

**Semantics.** Replaces the value with its 20-byte SHA-1 digest as raw bytes; combine
with `t:hexEncode` to compare against a hex string, as CRS does.

**Divergence notes.** None known.

**Tests.** `tests/unit/transformations/sha1.json`

### uppercase

**Status:** Core

**Syntax.** `t:uppercase`

**Semantics.** Converts ASCII letters `a`–`z` to upper case; other bytes unchanged.

**Divergence notes.** Coraza 3.8.1 uses `strings.ToUpper` (non-ASCII folding, lone
high bytes become U+FFFD); the Core cases are ASCII-only. Implemented by libmodsecurity v3 (`src/actions/transformations/
upper_case.cc`) and Coraza (Coraza ADR-0007); absent from ModSecurity v2, which is
therefore listed in `compat/known-gaps.md`. Promoted to Core by ADR-0012 as the design
seeded; it is the only Core feature one engine lacks by construction.

**Tests.** `tests/unit/transformations/uppercase-extra.json`

### urlDecodeUni

**Status:** Core

**Syntax.** `t:urlDecodeUni`

**Semantics.** Decodes `%XX`, `+` as space, and `%uXXXX` (IIS-style). A `%uXXXX`
sequence yields one byte: with a `SecUnicodeMapFile` loaded the mapping table applies;
otherwise full-width forms `%uFF01`–`%uFF5E` map to their ASCII counterparts and any
other code point yields its low 8 bits. Invalid `%` sequences are left as is and set
`URLENCODED_ERROR` where the engine tracks it.

**Divergence notes.** One corpus input differs between ModSecurity and Coraza on
full-width `%uFFxx` handling (`compat/known-gaps.md`); the imported case keeps the
ModSecurity expectation.

**Tests.** `tests/unit/transformations/urlDecodeUni.json`

### utf8toUnicode

**Status:** Core

**Syntax.** `t:utf8toUnicode`

**Semantics.** Replaces each well-formed multi-byte UTF-8 sequence (RFC 3629) with `%u`
followed by the code point in lowercase hexadecimal, at least four digits (five for code
points above U+FFFF); ASCII and malformed bytes are left unchanged.

**Divergence notes.** The engines agree only on well-formed input in the Basic
Multilingual Plane, which is all the imported corpus covers.

- Malformed input: libmodsecurity v3 (`utf8_to_unicode.cc`) drops a lead byte whose
  sequence is incomplete or invalid, and emits both `%u…` and the raw lead byte for an
  overlong or surrogate sequence; Coraza (`utf8_to_unicode.go`, Go `range` decoding)
  turns each malformed byte into `%ufffd` (`compat/known-gaps.md`). ModSecurity v2 leaves
  malformed bytes unchanged.
- Code points above U+FFFF: v3 and Coraza emit five digits as specified; v2
  (`utf8_unicode_inplace_ex`, `sprintf("%%u%04x")` advancing six bytes) lets the
  following byte overwrite the fifth digit. v2 and v3 also accept sequences above
  U+10FFFF (`F4 90`–`F4 BF`), which are not well-formed.
- NUL: a NUL byte is ASCII and is left unchanged by Coraza, as specified; v2 treats NUL
  as the lead byte of a two-byte sequence, emits `%u00XX` when the next byte is 0x80 or
  above and otherwise truncates the value there (`strlen`); v3 drops a NUL that is not the
  last byte.

**Tests.** `tests/unit/transformations/utf8toUnicode.json`,
`tests/unit/transformations/utf8toUnicode-extra.json`

## Extended transformations

Specified in outline; SHOULD be implemented.

### base64DecodeExt

**Status:** Extended

**Semantics.** Base64 decoding that skips every byte outside the alphabet, NUL included, and ignores `=` instead of stopping (Coraza ADR-0014 lineage; libmodsecurity v3 `decode_forgiven_engine`). The result when `=` follows a single dangling sextet is not specified (ModSecurity v2 `decode_base64_ext` and v3 return the empty value). ModSecurity v2 stops at a NUL byte (C string); Coraza 3.8.1 (`base64decode.go`) stops at `=`. Coraza, ModSecurity v2.9.15 (`msc_util.c`, `b64_reverse_t`) and libmodsecurity v3.0.17 (`src/utils/base64.cc`, `decode_forgiven_engine`) also accept the base64url alphabet (`-`, `_`), which earlier ModSecurity releases skip.

**Implemented by.** v2, v3, Coraza.

### base64Encode

**Status:** Extended

**Semantics.** Standard Base64 encoding of the value.

**Implemented by.** v2, v3, Coraza.

### hexDecode

**Status:** Extended

**Semantics.** Decodes every complete pair of bytes as two hexadecimal digits; a trailing odd byte is dropped. The result for a pair containing a byte that is not a hexadecimal digit is not specified (ModSecurity v2 `hex2bytes_inplace` and v3 `hex_decode.cc` apply their digit arithmetic to it; the corpus cases exercising this are excluded on import). Coraza 3.8.1 returns the input unchanged on an odd length (`compat/known-gaps.md`).

**Implemented by.** v2, v3, Coraza.

### md5

**Status:** Extended

**Semantics.** Replaces the value with its 16-byte MD5 digest as raw bytes.

**Implemented by.** v2, v3, Coraza.

### parityEven7bit

**Status:** Extended

**Semantics.** Sets bit 7 when the byte's eight-bit parity is odd and clears it otherwise,
so a byte whose bit 7 is already set keeps odd parity (ModSecurity v2 `re_tfns.c`,
libmodsecurity v3 `parity_even_7bit.h`).

**Implemented by.** v2, v3.

### parityOdd7bit

**Status:** Extended

**Semantics.** Clears bit 7 when the byte's eight-bit parity is odd and sets it otherwise;
the mirror of `parityEven7bit`, with the same high-bit caveat.

**Implemented by.** v2, v3.

### parityZero7bit

**Status:** Extended

**Semantics.** Clears the eighth bit of every byte.

**Implemented by.** v2, v3.

### removeComments

**Status:** Extended

**Semantics.** Removes C-style `/* ... */` and HTML `<!-- ... -->` comments; a SQL `--` or shell `#` outside a comment ends the value there. What follows a closing `*/` or `-->` is **not specified**: ModSecurity before v2.9.15 and v3.0.17 copies the next byte unexamined, so `/* x */` yields one NUL byte (the C string terminator); ModSecurity v2.9.15 (`re_tfns.c`) and libmodsecurity v3.0.17 (`remove_comments.cc`) carry on scanning and give the empty value. `tests/unit/transformations/removeComments.json` is maintained by hand and keeps only cases that do not depend on it. An unterminated comment yields one space. CRS prefers `removeCommentsChar`.

**Implemented by.** v2, v3, Coraza.

### replaceNulls

**Status:** Extended

**Semantics.** Replaces NUL bytes with spaces.

**Implemented by.** v2, v3, Coraza.

### sqlHexDecode

**Status:** Extended

**Semantics.** Decodes SQL `0xHH...` hexadecimal literals (`0x` or `0X` followed by at least one pair of hexadecimal digits) to their bytes; a `0x` with no complete pair is kept as is (libmodsecurity v3 `sql_hex_decode.cc`). ModSecurity v2 (`sql_hex2bytes_inplace`) copies the byte after a literal without examining it, so `0x410x42` yields `A0x42`, and truncates the value at a decoded NUL byte.

**Implemented by.** v2, v3.

### trim

**Status:** Extended

**Semantics.** Removes leading and trailing whitespace.

**Implemented by.** v2, v3, Coraza.

### trimLeft

**Status:** Extended

**Semantics.** Removes leading whitespace.

**Implemented by.** v2, v3, Coraza.

### trimRight

**Status:** Extended

**Semantics.** Removes trailing whitespace.

**Implemented by.** v2, v3, Coraza.

### urlDecode

**Status:** Extended

**Semantics.** Decodes `%XX` and `+` but not `%uXXXX`.

**Implemented by.** v2, v3, Coraza.

### urlEncode

**Status:** Extended

**Semantics.** Percent-encodes every byte outside the unreserved set.

**Implemented by.** v2, v3, Coraza.

