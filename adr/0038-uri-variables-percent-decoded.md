# ADR-0038: The URI variables are percent-decoded once, from phase 1

- **Status:** proposed
- **Date:** 2026-11-11
- **Deciders:** @fzipi
- **Category:** Divergence

## Context

`REQUEST_URI` was specified as sent, without decoding (`05-variables.md#request_uri`), and
whether `REQUEST_FILENAME` is decoded was left open (`05-variables.md#request_filename`).
Checked on 11 November 2026 with all three reference adapters, request target
`/d%20x/f%41+b.php?q=%41+b&r=%2526&s=%zz`:

| Variable | ModSecurity v2 | libmodsecurity v3 | Coraza |
|---|---|---|---|
| `REQUEST_URI` | as sent | `/d x/fA+b.php?q=A+b&r=%26&s=%zz` | as sent |
| `REQUEST_FILENAME` | as sent | `/d x/fA+b.php` | `/d x/fA+b.php` |
| `REQUEST_BASENAME` | as sent | `fA+b.php` | `fA+b.php` |
| `QUERY_STRING`, `REQUEST_URI_RAW` | as sent | as sent | as sent |

- ModSecurity v2 (v2/master, 2026-09): `var_request_uri_generate` and
  `var_request_filename_generate` (`apache2/re_variables.c`) read Apache's
  `r->parsed_uri.path` and `.query`, which are not decoded.
- libmodsecurity v3 (v3.0.17): `Transaction::processURI` (`src/transaction.cc`) decodes the
  target with `utils::uri_decode` (`src/utils/decode.cc`) before phase 1 and builds
  `REQUEST_URI`, `REQUEST_FILENAME` and `REQUEST_BASENAME` from the result. `uri_decode`
  replaces `%` and two hexadecimal digits by that byte, keeps any other `%`, keeps `+`, and
  runs once. `QUERY_STRING` and `REQUEST_URI_RAW` are taken from the target as sent.
- Coraza (v3.8.1): `Transaction.ProcessURI` (`internal/corazawaf/transaction.go`) sets
  `REQUEST_URI` from `url.URL.String()`, which re-encodes rather than decodes, and
  `REQUEST_FILENAME` and `REQUEST_BASENAME` from `url.URL.Path`, which Go has decoded.

The SecLang round table (ModSecurity, Coraza, CRS and CloudLinux maintainers) took this up
in 2024. Its notes record that the decoding itself has to be defined before engines
converge on it, and that `t:urlDecode` turning `+` into a space is wrong for a path. On
4 April 2024 it settled the question (dune73, OWASP Slack): "we settled on implicit
decoding of REQUEST_URI starting in phase 1. So the desired behavior is the current
ModSec3 behavior and ModSec2 will see a breaking change". The notes list
`REQUEST_FILENAME_RAW`, `REQUEST_BASENAME_RAW`, `QUERY_STRING_RAW` and `PATH_INFO_RAW` as
the "friends" that go with it.

## Decision

1. **URI percent-decoding** replaces every `%` followed by two hexadecimal digits (either
   case) with the byte they encode (RFC 3986 §2.1). Everything else is kept as sent: `+`, a
   `%` not followed by two hexadecimal digits, and `%u` sequences. It runs once, so
   `%2526` becomes `%26`. It is not `t:urlDecode`, which also turns `+` into a space.
2. `REQUEST_URI` MUST be the request path and query, without scheme and host, after URI
   percent-decoding. Scheme and host are removed from the target as sent, before
   decoding, so an encoded `%2F%2F` is never taken for the `//` that starts a host. `REQUEST_FILENAME` MUST be its path, the part before the first `?` of
   the target as sent, after URI percent-decoding; `REQUEST_BASENAME` follows from it.
3. These values MUST be set before phase 1 and MUST be the same in every phase.
4. `REQUEST_URI_RAW` and `QUERY_STRING` stay as sent. Two Extended variables keep the
   other two as sent: `REQUEST_FILENAME_RAW` (the path) and `REQUEST_BASENAME_RAW` (its
   last segment).
5. Decoding can produce any byte, including NUL, `/`, `\` and `?`. A rule that depends on
   the request's own delimiters or on the encoding reads a raw variable.

## Options considered

- **Implicit decoding from phase 1, v3's behaviour (chosen).** The round table's
  decision. A rule sees what the backend serves without adding a transformation, and two
  engines already decode `REQUEST_FILENAME`.
- **Keep the URI variables as sent (v2's behaviour).** Lossless, and `t:urlDecodeUni`
  can always be added. Rejected by the round table: every rule has to remember to decode,
  and the transformations that do it also decode `+`.
- **Explicit decoding with `t:urlDecode`.** Rejected: `+` becomes a space in the path,
  and each rule chooses its own decoding.
- **Decode `+` as well, as form decoding does.** Rejected: `+` is a space only in
  `application/x-www-form-urlencoded` data, which is how `ARGS` are already decoded; in a
  path it is a literal `+`.
- **Decode until nothing changes.** Rejected: double encoding is itself a signal, and the
  raw variables would no longer be the only way to see it.
- **`QUERY_STRING_RAW` and a decoded `QUERY_STRING`.** Rejected: a decoded query string
  merges encoded and literal `&` and `=`, and `ARGS_GET` already gives the decoded values.
- **`PATH_INFO_RAW`.** Deferred: `PATH_INFO` is Extended and its value depends on the host
  server (`05-variables.md#path_info`).

## Consequences

- For ModSecurity v2: a breaking change. `REQUEST_URI`, `REQUEST_FILENAME` and
  `REQUEST_BASENAME` are decoded before phase 1. A rule matching encoded text in them,
  for example `%2e%2e`, moves to `REQUEST_URI_RAW` or `REQUEST_FILENAME_RAW`.
- For libmodsecurity v3: no change in what it decodes. It removes scheme and host before
  decoding rather than after (`Transaction::processURI` searches the decoded target for
  `//`), and adds the two `_RAW` variables.
- For Coraza: `REQUEST_URI` is decoded, and the two `_RAW` variables are added.
- For rule authors:
  - Applying `t:urlDecode` or `t:urlDecodeUni` to a URI variable decodes twice. Drop the
    transformation, or apply it to the `_RAW` variable. OWASP CRS v4.25.2 does neither
    on `REQUEST_URI`.
  - CRS 920260 looks for `%uff` in `REQUEST_URI`. It still finds a literal `%uff`, which
    is not decoded, and it now also finds `%25uff`. CRS 920460 and 920540 now see a
    backslash sent as `%5C` on v2 and Coraza, as they already do on v3.
  - Rulesets that have to run on engines on both sides of the change need a way to tell
    them apart; ADR-0039 proposes `ENGINE_FLAGS:uri_decoding`.

## Tests

- `tests/engine/variables/request-uri-decoded.yaml`

## References

- SecLang round table notes, meeting 01 (2024-03-13) and "Jobs and Decisions":
  https://docs.google.com/document/d/1ZmVuc8TYk7ylUnhU0vp06WeZq_QqCw6XlmRssEaHDv0
- Round table decision, OWASP Slack, 4 April 2024:
  https://owasp.slack.com/archives/C069PCXSW12/p1712212477264069
- RFC 3986 §2.1, percent-encoding: https://www.rfc-editor.org/rfc/rfc3986#section-2.1
- `05-variables.md#request_uri`, `05-variables.md#request_filename`,
  `07-transformations.md#urldecode`
