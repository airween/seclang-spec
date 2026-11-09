# 06. Operators

An operator tests one value of the variable list (`02-grammar.md#operator`). The index
lists every operator name known to any surveyed engine with its status
(`00-conventions.md`); aliases are listed under their canonical name (ADR-0004).

Unit-tier cases for operators live in `tests/unit/operators/`, imported from the SecRules
Test Set by `tools/import_sts.py` (`tests/README.md`).

## Index

| Operator | Status | v2 | v3 | Coraza | Purpose |
|---|---|---|---|---|---|
| [beginsWith](#beginswith) | Core | yes | yes | yes | Value starts with the parameter |
| [contains](#contains) | Core | yes | yes | yes | Value contains the parameter |
| [containsWord](#containsword) | Extended | yes | yes | - | Value contains the parameter as a whole word |
| [detectSQLi](#detectsqli) | Core | yes | yes | yes | libinjection SQL injection detector |
| [detectXSS](#detectxss) | Core | yes | yes | yes | libinjection XSS detector |
| [endsWith](#endswith) | Core | yes | yes | yes | Value ends with the parameter |
| [eq](#eq) | Core | yes | yes | yes | Numeric equality |
| [fuzzyHash](#fuzzyhash) | Extended | yes | yes | - | ssdeep fuzzy hash comparison |
| [ge](#ge) | Core | yes | yes | yes | Numeric greater-or-equal |
| [geoLookup](#geolookup) | Extended | yes | yes | yes | GeoIP lookup into GEO |
| [gsbLookup](#gsblookup) | Deprecated | yes | yes | - | Google Safe Browsing lookup |
| [gt](#gt) | Core | yes | yes | yes | Numeric greater-than |
| [inspectFile](#inspectfile) | Extended | yes | yes | yes | Run an external program or Lua script on an uploaded file |
| [ipMatch](#ipmatch) | Core | yes | yes | yes | IP address or CIDR list match |
| [ipMatchF](#ipmatchfromfile) | alias of [ipMatchFromFile](#ipmatchfromfile) | yes | yes | yes | Alias of ipMatchFromFile |
| [ipMatchFromDataset](#ipmatchfromdataset) | Engine-specific | - | - | yes | Coraza: ipMatch against a SecDataset |
| [ipMatchFromFile](#ipmatchfromfile) | Extended | yes | yes | yes | ipMatch against addresses in a file |
| [le](#le) | Core | yes | yes | yes | Numeric less-or-equal |
| [lt](#lt) | Core | yes | yes | yes | Numeric less-than |
| [noMatch](#nomatch) | Extended | yes | yes | yes | Never matches |
| [pm](#pm) | Core | yes | yes | yes | Case-insensitive multi-phrase match |
| [pmf](#pmfromfile) | alias of [pmFromFile](#pmfromfile) | yes | yes | yes | Alias of pmFromFile |
| [pmFromDataset](#pmfromdataset) | Engine-specific | - | - | yes | Coraza: pm against a SecDataset |
| [pmFromFile](#pmfromfile) | Core | yes | yes | yes | pm with phrases from a file |
| [rbl](#rbl) | Extended | yes | yes | yes | DNS blocklist lookup |
| [restpath](#restpath) | Engine-specific | - | - | yes | Coraza: match a REST path template and extract ARGS_PATH |
| [rsub](#rsub) | Deprecated | yes | yes | - | Regex substitution in STREAM_* variables |
| [rx](#rx) | Core | yes | yes | yes | Regular expression match |
| [rxGlobal](#rxglobal) | Engine-specific | - | yes | - | v3: rx matching every occurrence |
| [streq](#streq) | Core | yes | yes | yes | String equality |
| [strmatch](#strmatch) | Extended | yes | yes | yes | Fixed-string match |
| [unconditionalMatch](#unconditionalmatch) | Core | yes | yes | yes | Always matches |
| [validateByteRange](#validatebyterange) | Core | yes | yes | yes | Any byte outside the permitted ranges |
| [validateDTD](#validatedtd) | Extended | yes | yes | - | Validate XML against a DTD |
| [validateHash](#validatehash) | Extended | yes | yes | - | Hash engine link check |
| [validateNid](#validatenid) | Engine-specific | - | - | yes | Coraza: validate a national id number |
| [validateSchema](#validateschema) | Extended | yes | yes | yes | Validate XML against an XML Schema |
| [validateUrlEncoding](#validateurlencoding) | Core | yes | yes | yes | Invalid URL encoding present |
| [validateUtf8Encoding](#validateutf8encoding) | Core | yes | yes | yes | Invalid UTF-8 present |
| [verifyCC](#verifycc) | Extended | yes | yes | - | Credit card number check (Luhn) |
| [verifyCPF](#verifycpf) | Extended | yes | yes | - | Brazilian CPF check |
| [verifySSN](#verifyssn) | Extended | yes | yes | - | US SSN check |
| [verifySVNR](#verifysvnr) | Engine-specific | - | yes | - | v3: Austrian SVNR check |
| [within](#within) | Core | yes | yes | yes | Value is a substring of the parameter |

## Regular expressions

### @rx PCRE extensions

**Status:** Extended

**Semantics.** Regular-expression syntax beyond the Core subset defined under `rx`
(lookahead and lookbehind, backreferences, possessive quantifiers, `\K`, recursion,
Unicode properties beyond `\p{L}`-style classes that RE2 lacks). Available on ModSecurity
v2 (PCRE) and libmodsecurity v3 (PCRE2); not on Coraza (Go `regexp`). Rules that need
them are not portable. See ADR-0018.

**Tests.** `tests/unit/operators/rx-pcre-extra.json`

## Core operators

### beginsWith

**Status:** Core

**Syntax.** `@beginsWith STRING` (macros expand).

**Semantics.** Matches when the value starts with `STRING`, byte-wise and
case-sensitively. An empty `STRING` matches every value.

**Divergence notes.** None known.

**Tests.** `tests/unit/operators/beginsWith.json`

### contains

**Status:** Core

**Syntax.** `@contains STRING` (macros expand).

**Semantics.** Matches when `STRING` occurs anywhere in the value, byte-wise and
case-sensitively. An empty `STRING` matches every value.

**Divergence notes.** Coraza 3.8.1 rejects an operator with an empty parameter at load
time ("empty data"); this affects `@beginsWith`, `@contains`, `@endsWith`, `@streq` and
`@within` alike (`compat/known-gaps.md`). ModSecurity accepts it, as the corpus cases
inherited from its unit tests show.

**Tests.** `tests/unit/operators/contains.json`

### detectSQLi

**Status:** Core

**Syntax.** `@detectSQLi`

**Semantics.** Runs the libinjection SQL injection detector on the value; matches when it
reports an injection fingerprint. With `capture`, `TX:0` receives the fingerprint. The
detector version is not pinned: the engine tests use inputs every libinjection release
classifies the same way.

**Divergence notes.** ModSecurity v2 and v3 embed the C library; Coraza uses its Go port
(`internal/operators/detect_sqli.go`). Fingerprint tables may lag between ports.

**Tests.** `tests/unit/operators/detectSQLi.json`,
`tests/engine/operators/detect-sqli-xss.yaml`

### detectXSS

**Status:** Core

**Syntax.** `@detectXSS`

**Semantics.** Runs the libinjection XSS detector on the value; matches when it reports
cross-site scripting.

**Divergence notes.** As `detectSQLi`.

**Tests.** `tests/unit/operators/detectXSS.json`,
`tests/engine/operators/detect-sqli-xss.yaml`

### endsWith

**Status:** Core

**Syntax.** `@endsWith STRING` (macros expand).

**Semantics.** Matches when the value ends with `STRING`, byte-wise and case-sensitively.

**Divergence notes.** None known.

**Tests.** `tests/unit/operators/endsWith.json`

### eq

**Status:** Core

**Syntax.** `@eq NUMBER` (macros expand).

**Semantics.** Converts the parameter and the value to integers and matches when they
are equal. A string that is not an integer, including the empty string, converts to 0
(ModSecurity v2 `atoi`, libmodsecurity v3 `std::stoi` with a catch, Coraza
`strconv.Atoi` ignoring the error). Leading digits followed by text convert to the digits
in v2 and v3 and to 0 in Coraza: **not specified**, and no test uses such a value.

**Divergence notes.** The partial-number case above.

**Tests.** `tests/unit/operators/eq.json`, `tests/engine/operators/numeric.yaml`

### ge

**Status:** Core

**Syntax.** `@ge NUMBER`

**Semantics.** Numeric greater-than-or-equal, conversions as `eq`.

**Divergence notes.** As `eq`.

**Tests.** `tests/unit/operators/ge.json`, `tests/engine/operators/numeric.yaml`

### gt

**Status:** Core

**Syntax.** `@gt NUMBER`

**Semantics.** Numeric greater-than, conversions as `eq`.

**Divergence notes.** As `eq`.

**Tests.** `tests/unit/operators/gt.json`, `tests/engine/operators/numeric.yaml`

### ipMatch

**Status:** Core

**Syntax.** `@ipMatch LIST` where `LIST` is comma-separated IPv4 or IPv6 addresses,
each optionally with a `/prefix` CIDR suffix.

**Semantics.** Matches when the value, parsed as an IP address, equals one of the
addresses or falls inside one of the networks. A value that is not an address does not
match. Mixed IPv4 and IPv6 entries are allowed in one list. Every entry of `LIST` MUST
be a valid address or prefix; an entry that cannot be parsed (for example
`10.0.0.0/100`) is a configuration error (ADR-0024). Entries MAY overlap or repeat:
the list matches when any entry does, so an entry covered by another changes nothing and
is not an error. An engine MAY warn when one entry lies entirely inside another, since
that can be a mistyped prefix.

**Divergence notes.** One corpus case differs: the IPv4-mapped address
`::ffff:ffff:ffff` against `0:0::/80` matches in ModSecurity and not in Coraza
(`compat/known-gaps.md`). The imported case keeps the ModSecurity expectation. Coraza
3.8.1 skips an unparsable entry (`internal/operators/ip_match.go`, `continue` on a
`ParseCIDR` error) where ModSecurity v2 (`apache2/re_operators.c`
`msre_op_ipmatch_param_init`) and v3 reject the rule; the corpus case asserting a
non-match for `10.0.0.0/100` is excluded on import (ADR-0024).

**Tests.** `tests/unit/operators/ipMatch.json`, `tests/engine/operators/ipmatch.yaml`,
`tests/engine/operators/ipmatch-invalid-entry.yaml`, `tests/engine/operators/ipmatch-overlap.yaml`

### le

**Status:** Core

**Syntax.** `@le NUMBER`

**Semantics.** Numeric less-than-or-equal, conversions as `eq`.

**Divergence notes.** As `eq`.

**Tests.** `tests/unit/operators/le.json`, `tests/engine/operators/numeric.yaml`

### lt

**Status:** Core

**Syntax.** `@lt NUMBER`

**Semantics.** Numeric less-than, conversions as `eq`. CRS uses it 190 times to compare
anomaly scores against thresholds.

**Divergence notes.** As `eq`.

**Tests.** `tests/unit/operators/lt.json`, `tests/engine/operators/numeric.yaml`

### pm

**Status:** Core

**Syntax.** `@pm PHRASE [PHRASE ...]` (space-separated).

**Semantics.** Matches when any phrase occurs in the value. Matching is
case-insensitive. A phrase may contain bytes written as `|hex|`, e.g. `|0a|`. Engines
implement it with an Aho-Corasick automaton, so the number of phrases does not affect
rule cost.

**Divergence notes.** With `capture`, ModSecurity v2 and libmodsecurity v3 store the
matched phrase in `TX:0`; Coraza does not. Capturing with `@pm` is therefore not portable.

**Tests.** `tests/unit/operators/pm.json`, `tests/unit/operators/pm-extra.json`

### pmFromFile

**Status:** Core

**Syntax.** `@pmFromFile PATH [PATH ...]`; alias `@pmf`.

**Semantics.** As `pm`, with phrases read one per line from each file; empty lines and
lines starting with `#` are ignored; a relative `PATH` resolves against the directory of
the configuration file containing the rule. A missing file MUST be a configuration error.

**Divergence notes.** None known. Aliases: ADR-0004.

**Tests.** `tests/engine/operators/pmfromfile.yaml`

### rx

**Status:** Core

**Syntax.** `@rx REGEX`, or simply `REGEX` (implicit operator, `02-grammar.md#operator`).

**Semantics.** Matches when `REGEX` matches anywhere in the value (unanchored). The
Core syntax is the subset shared by PCRE, PCRE2 and RE2: literals, `.`, character
classes and `\d \w \s` with negations, `\b`, byte escapes `\xhh` and `\x{hh}`, the anchors `^ $ \A \z` (not `\Z`, which RE2 lacks), alternation, grouping with `(...)`
and `(?:...)`, greedy and lazy quantifiers `* + ? {m,n}`, inline flags `(?i)`, `(?s)`,
`(?m)` (not `(?x)`, which RE2 rejects). Named groups MUST use `(?P<name>...)`, which all three accept. Anything
in `#rx-pcre-extensions` is not Core (ADR-0018). The pattern is matched in dot-all mode:
`.` matches every byte including the newline. Whether `^` and `$` match at inner line
boundaries without `(?m)` is **not specified** (ADR-0027): rules that need line anchors
MUST write `(?m)`. With `capture`, `TX:0` receives the
whole match and `TX:1`…`TX:9` the groups; unit cases carry them as `re_groups`.

**Divergence notes.** ModSecurity v2 uses PCRE, libmodsecurity v3 PCRE2, Coraza Go
`regexp` (RE2). OWASP CRS v4 is written within the Core subset and checked by its
toolchain. Match limits (`SecPcreMatchLimit`) apply to PCRE engines only. Compile
options differ: v2 `PCRE_DOTALL | PCRE_DOLLAR_ENDONLY` (`apache2/re_operators.c`), v3.0.16
`PCRE2_DOTALL | PCRE2_MULTILINE` (`src/utils/regex.cc`), Coraza v3.8.1 `(?sm)` by default
(`internal/operators/rx.go`); see ADR-0027.

**Tests.** `tests/unit/operators/rx.json`, `tests/engine/operators/rx-capture.yaml`,
`tests/engine/operators/rx-dotall.yaml`

### streq

**Status:** Core

**Syntax.** `@streq STRING` (macros expand).

**Semantics.** Matches when the value equals `STRING` byte for byte.

**Divergence notes.** None known.

**Tests.** `tests/unit/operators/streq.json`

### unconditionalMatch

**Status:** Core

**Syntax.** `@unconditionalMatch`

**Semantics.** Always matches, once per selected value. A rule whose variable list
selects no values does not match, whatever the operator (all three engines skip
evaluation: v2 `apache2/re.c` iterates zero targets and returns `RULE_NO_MATCH` when
nothing matched, v3 `rule_with_operator.cc`, Coraza `rule.go` `len(matchedValues) == 0`);
use `SecAction` for an unconditional rule.

**Divergence notes.** The operator takes no parameter. libmodsecurity v3's scanner
recognises it only bare: `@unconditionalMatch X` is lexed as an `@rx` pattern
(`seclang-scanner.ll`). The corpus case carrying a stray parameter is excluded on
import.

**Tests.** `tests/unit/operators/unconditionalMatch.json`

### validateByteRange

**Status:** Core

**Syntax.** `@validateByteRange RANGES`, comma-separated single bytes or `LOW-HIGH`
ranges in decimal, e.g. `9,10,13,32-126`.

**Semantics.** Matches when any byte of the value is outside every listed range. An
empty parameter, or one containing anything but decimal numbers, `-` and `,`, MUST be a
configuration error.

**Divergence notes.** ModSecurity v2 rejects an empty parameter but parses `xxx` as the
single value 0 (`re_operators.c`, `atoi`); libmodsecurity v3 and Coraza reject both. The
corpus cases with those parameters are excluded on import (`tools/import_sts.py`,
`EXCLUDED_CASES`).

**Tests.** `tests/unit/operators/validateByteRange.json`

### validateUrlEncoding

**Status:** Core

**Syntax.** `@validateUrlEncoding`

**Semantics.** Matches when the value contains a `%` not followed by two hexadecimal
digits. Intended for values that are still URL-encoded (`REQUEST_URI_RAW`, raw bodies).

**Divergence notes.** None known.

**Tests.** `tests/unit/operators/validateUrlEncoding.json`

### validateUtf8Encoding

**Status:** Core

**Syntax.** `@validateUtf8Encoding`

**Semantics.** Matches when the value is not well-formed UTF-8: truncated sequences,
invalid continuation bytes, overlong encodings, or code points above U+10FFFF.

**Divergence notes.** None known. (The Phase 1 matrix wrongly listed Coraza as lacking
it; `internal/operators/validate_utf8_encoding.go` registers it.)

**Tests.** `tests/unit/operators/validateUtf8Encoding.json`

### within

**Status:** Core

**Syntax.** `@within STRING` (macros expand).

**Semantics.** Matches when the **value** occurs as a substring of `STRING`, the reverse
of `contains`. CRS uses it to test a method against an allow-list
(`REQUEST_METHOD "!@within %{tx.allowed_methods}"`). An empty value matches.

**Divergence notes.** None known.

**Tests.** `tests/unit/operators/within.json`

## Extended operators

Specified in outline; SHOULD be implemented.

### containsWord

**Status:** Extended

**Semantics.** Matches when the parameter occurs in the value at a position preceded by the start of the value or a non-word byte and followed by the end of the value or a non-word byte; the empty parameter matches every value. Word bytes are the ASCII letters (libmodsecurity v3 `src/operators/contains_word.cc`, `acceptableChar`); ModSecurity v2 (`apache2/re_operators.c`, `msre_op_containsWord_execute`) also counts digits and `_`, so `def` is a word in `0def` for v3 and not for v2. The corpus follows v3.

**Implemented by.** v2, v3.

### fuzzyHash

**Status:** Extended

**Semantics.** Compares the value's ssdeep hash against hashes in a file with a threshold.

**Implemented by.** v2, v3.

### geoLookup

**Status:** Extended

**Semantics.** Looks the value up as an IP address in the `SecGeoLookupDb` database and fills the `GEO` collection; matches on success.

**Implemented by.** v2, v3, Coraza.

### inspectFile

**Status:** Extended

**Semantics.** Runs an external program or Lua script against an uploaded file and matches on its verdict. Filesystem and process access make it Extended.

**Implemented by.** v2, v3, Coraza.

### ipMatchFromFile

**Status:** Extended

**Semantics.** As `ipMatch`, with addresses read one per line from a file; alias `@ipMatchF` (ADR-0004).

**Implemented by.** v2, v3, Coraza.

### noMatch

**Status:** Extended

**Semantics.** Never matches. Used to disable a rule without removing it.

**Implemented by.** v2, v3, Coraza.

### rbl

**Status:** Extended

**Semantics.** Looks the value up as an address in a DNS blocklist named by the parameter; `SecHttpBlKey` enables Project Honey Pot queries.

**Implemented by.** v2, v3, Coraza.

### strmatch

**Status:** Extended

**Semantics.** Matches when the parameter occurs anywhere in the value, byte-wise and case-sensitively, like `contains`; engines implement it with Boyer-Moore-Horspool. `contains` is preferred.

**Implemented by.** v2, v3, Coraza.

### validateDTD

**Status:** Extended

**Semantics.** Validates the XML body against a DTD and matches on failure.

**Implemented by.** v2, v3.

### validateHash

**Status:** Extended

**Semantics.** Hash-engine check of a URL; part of the Deprecated hash engine.

**Implemented by.** v2, v3.

### validateSchema

**Status:** Extended

**Semantics.** Validates the XML body against an XML Schema file and matches on failure.

**Implemented by.** v2, v3, Coraza.

### verifyCC

**Status:** Extended

**Semantics.** The parameter is a regular expression compiled dot-all and multiline (`.` matches a newline, `^` and `$` match at line boundaries). Matches are searched from each offset of the value in turn, anchors relative to the whole value; an empty match is skipped (ModSecurity v2 passes PCRE `NOTEMPTY`, which backtracks to a non-empty match at the same offset, so a pattern with an empty alternative such as `(?:|\d{16})` matches in v2 only; libmodsecurity v3 skips it); the digits of each whole match are checked with the Luhn algorithm, and the first Luhn-valid match matches (ModSecurity v2 `apache2/re_operators.c`, `msre_op_verifyCC_execute` and `luhn_verify`).

**Implemented by.** v2, v3.

### verifyCPF

**Status:** Extended

**Semantics.** Searched like `verifyCC`; a match is valid when its first eleven digits are exactly eleven, are not `00000000000`, `11111111111` … `99999999999` or `01234567890`, and the last two agree with the CPF check-digit sums (weights 10…2 and 11…2, remainder below 2 giving 0, otherwise 11 minus the remainder) (ModSecurity v2 `cpf_verify`). libmodsecurity v3.0.16 searches each suffix of the value as a separate subject (`src/operators/verify_cpf.cc`, `VerifyCPF::evaluate`), so `^` and look-behind context are relative to the suffix, not the whole value.

**Implemented by.** v2, v3.

### verifySSN

**Status:** Extended

**Semantics.** Searched like `verifyCC`; a match is valid when it holds exactly nine digits that are neither all ascending by one nor all equal, with area (first three), group (next two) and serial (last four) non-zero, area not 666 and below 740 (ModSecurity v2 `ssn_verify`). libmodsecurity v3.0.16 searches each suffix of the value as a separate subject (`src/operators/verify_ssn.cc`, `VerifySSN::evaluate`), so `^` and look-behind context are relative to the suffix, not the whole value.

**Implemented by.** v2, v3.


## Deprecated operators

MUST be accepted by the parser and MAY never match (ADR-0011).

### rsub

**Status:** Deprecated

**Semantics.** Regular-expression substitution inside `STREAM_INPUT_BODY`/`STREAM_OUTPUT_BODY`; requires stream inspection (Deprecated directives).

**Implemented by.** v2, v3.

### gsbLookup

**Status:** Deprecated

**Semantics.** Google Safe Browsing lookup; the API it used was retired (ADR-0011).

**Implemented by.** v2, v3.


## Engine-specific operators

Reserved names; not specified (ADR-0010).

### ipMatchFromDataset

**Status:** Engine-specific

**Semantics.** Coraza: `ipMatch` against a `SecDataset`.

**Implemented by.** Coraza.

### pmFromDataset

**Status:** Engine-specific

**Semantics.** Coraza: `pm` against a `SecDataset`.

**Implemented by.** Coraza.

### restpath

**Status:** Engine-specific

**Semantics.** Coraza: matches a REST path template like `/users/{id}` and stores the placeholders in `ARGS_PATH`.

**Implemented by.** Coraza.

### rxGlobal

**Status:** Engine-specific

**Semantics.** libmodsecurity v3: like `rx` but matches every occurrence and captures all of them.

**Implemented by.** v3.

### validateNid

**Status:** Engine-specific

**Semantics.** Coraza: validates national identification numbers by country code.

**Implemented by.** Coraza.

### verifySVNR

**Status:** Engine-specific

**Semantics.** libmodsecurity v3: Austrian social insurance number check.

**Implemented by.** v3.

