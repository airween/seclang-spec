# ADR-0022: `REQUEST_BODY` without a body processor

- **Status:** accepted
- **Date:** 2026-10-07
- **Accepted:** 2026-11-09
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween
- **Category:** Divergence

## Context

What `REQUEST_BODY` holds when the request has a body but no processor applies (a
`Content-Type` other than urlencoded or multipart, and no `ctl:requestBodyProcessor`):

- ModSecurity v2 (`apache2/re_variables.c` `var_request_body_generate`,
  `apache2/msc_reqbody.c`): the variable is **absent** unless the processor was
  `URLENCODED` or `ctl:forceRequestBodyVariable=On` built the buffer; a rule targeting it
  then has no values and does not match.
- libmodsecurity v3 (`src/transaction.cc`, the single writer: `if
  (m_requestBody.tellp() > 0) m_variableRequestBody.set(...)`): **populated** with the
  raw body whenever one was buffered, for every content type including multipart.
  `ctl:forceRequestBodyVariable` is parsed (`seclang-parser.yy`) but has no
  implementation under `src/actions/ctl/`.
- Coraza 3.8.1 (`internal/corazawaf/transaction.go`): **empty** without a processor;
  with `ctl:forceRequestBodyVariable=On` it selects the `URLENCODED` processor, which
  populates `REQUEST_BODY` and also parses the body into `ARGS_POST`.

The reference manual says `REQUEST_BODY` is available for `URLENCODED` bodies or when
forced. OWASP CRS rule 200004 and several user rules rely on
`ctl:forceRequestBodyVariable` to inspect bodies of unusual content types.

## Decision

`REQUEST_BODY` MUST hold the raw body when the processor is `URLENCODED`, and when
`ctl:forceRequestBodyVariable=On` was set in phase 1 regardless of content type. Its value
when neither applies is **not specified**. Forcing MUST NOT be required to also parse the
body into `ARGS_POST`; whether it does is unspecified. Normative text:
`spec/05-variables.md#request_body`, `spec/09-body-processors.md#processor-selection`.

## Options considered

- v3 behaviour (always populated): simplest for rule authors, but changes v2 and Coraza
  and makes multipart bodies visible to regex rules with a large cost; deferred.
- v2 behaviour (absent unless forced): matches the manual, but "absent" versus "empty" is
  itself unobservable in portable tests; rejected as a MUST.
- Specify only the two cases every engine documents (chosen).

## Consequences

- For libmodsecurity v3: implement `ctl:forceRequestBodyVariable` (a Core option it only
  parses today); listed in `compat/known-gaps.md`.
- For Coraza: forcing also parses `ARGS_POST`; permitted, documented as a divergence.
- For rule authors: set `ctl:forceRequestBodyVariable=On` in phase 1 before reading
  `REQUEST_BODY` for non-form bodies, as CRS does.

## Tests

- `tests/engine/body/no-processor.yaml`
- `tests/engine/actions/ctl-options.yaml` (forceRequestBodyVariable entry)

## References

- `spec/05-variables.md#request_body`, `spec/09-body-processors.md#processor-selection`
