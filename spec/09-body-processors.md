# 09. Body processors

A body processor turns a request body into variables: `ARGS_POST`, `FILES*`, `XML`,
`REQUEST_BODY` and the error variables (`05-variables.md`). This file defines when each
processor runs and what it produces. Limits that bound the work are directives
(`04-directives.md`: `SecRequestBodyLimit`, `SecRequestBodyNoFilesLimit`,
`SecRequestBodyJsonDepthLimit`, `SecUploadFileLimit`).

### Processor selection

**Status:** Core

**Semantics.** When `SecRequestBodyAccess` is `On` (or forced by `ctl:requestBodyAccess`
in phase 1), the engine buffers the request body and, before phase 2, selects a
processor from the request `Content-Type` by **prefix** match, so parameters such as
`; charset=utf-8` are ignored:

| `Content-Type` prefix | Processor | `REQBODY_PROCESSOR` |
|---|---|---|
| `application/x-www-form-urlencoded` | `#urlencoded` | `URLENCODED` |
| `multipart/form-data` | `#multipart` | `MULTIPART` |
| anything else | none | empty |

`XML` and `JSON` are never selected from the content type: a phase 1 rule selects them
with `ctl:requestBodyProcessor=XML|JSON`, as the recommended configurations do for
`text/xml`, `application/xml` and `application/json` (rules 200000 and 200001). With no
processor the body is still buffered against `SecRequestBodyLimit` and `ARGS_POST` stays
empty. `REQUEST_BODY` MUST hold the body when `ctl:forceRequestBodyVariable=On` was set in
phase 1; without forcing its value is **not specified** (ADR-0022). Processor selection
MUST NOT itself set `REQBODY_ERROR`.

**Divergence notes.** Selection itself agrees (v2 `apache2/mod_security2.c`, v3
`src/transaction.cc` `m_requestBodyType`, Coraza `internal/corazawaf/transaction.go`).
`REQUEST_BODY` without a processor is absent in v2, populated in v3 and empty in Coraza;
`ctl:forceRequestBodyVariable` is unimplemented in libmodsecurity v3 and, in Coraza, also
parses the body as `URLENCODED` into `ARGS_POST`. See ADR-0022 and `compat/known-gaps.md`.

**Tests.** `tests/engine/body/selection.yaml`, `tests/engine/body/no-processor.yaml`

### URLENCODED

**Status:** Core

**Semantics.** Splits the body on `SecArgumentSeparator` (default `&`), then each pair on
its first `=`; a pair without `=` is a name with an empty value; an empty pair is ignored.
Names and values are URL-decoded non-strictly: `+` becomes a space, `%XX` becomes the
byte, and a `%` not followed by two hexadecimal digits is kept literally. Each pair becomes
an `ARGS_POST` member in body order, subject to `SecArgumentsLimit`. `REQUEST_BODY` holds
the raw body and `REQUEST_BODY_LENGTH` its size.

**Divergence notes.** An invalid `%` sequence sets `URLENCODED_ERROR` to 1 in ModSecurity
v2 (`apache2/msc_parsers.c`, `urldecode_nonstrict_inplace_ex`) and libmodsecurity v3
(`src/transaction.cc`); Coraza never sets that variable, which is why it is Extended
(`05-variables.md`).

**Tests.** `tests/engine/body/urlencoded.yaml`

### MULTIPART

**Status:** Core

**Semantics.** Parses `multipart/form-data` (RFC 7578) using the `boundary` parameter of
the `Content-Type`. Each part's `Content-Disposition` names a field. A part **with** a
`filename` parameter is a file: it appears in `FILES` (value: the file name), `FILES_NAMES`
(the field name), `FILES_SIZES` and `FILES_COMBINED_SIZE`; its content is not exposed as
a variable (engines may store it under `SecUploadDir`). A part **without** `filename` is an
argument: an `ARGS_POST` member named by the field. `MULTIPART_PART_HEADERS` holds each
part's raw headers. `REQUEST_BODY` is not specified for multipart bodies (ADR-0022).
Parsing anomalies set
`MULTIPART_STRICT_ERROR` (`05-variables.md#multipart_strict_error`); the number of file
parts is capped by `SecUploadFileLimit` (Extended); non-file bytes count against
`SecRequestBodyNoFilesLimit`.

**Divergence notes.** Which anomalies set the strict-error flag differs by engine; the
Core tests use well-formed bodies with CRLF line endings.

**Tests.** `tests/engine/body/multipart-fields.yaml`,
`tests/engine/body/multipart-two-files.yaml`, `tests/engine/variables/multipart.yaml`

### XML

**Status:** Core

**Semantics.** Parses the body as XML and exposes it through the `XML` collection
(`05-variables.md#xml`: `XML:/*` and `XML://@*` are Core). External entities MUST NOT be
resolved unless `SecXmlExternalEntity On` (Extended) is configured; a document that
declares one still parses, with the reference left unexpanded. A document the parser
rejects sets `REQBODY_ERROR` and `REQBODY_ERROR_MSG`.

**Divergence notes.** ModSecurity v2 (`apache2/msc_xml.c`, `xml_external_entity == 0`)
and libmodsecurity v3 (`src/request_body_processor/xml.cc`, `m_secXMLExternalEntity`) use
libxml2 and reject malformed documents; Coraza (`internal/bodyprocessors/xml.go`) uses Go's
`encoding/xml` in non-strict mode with HTML entities and never loads external entities, so
it accepts some documents libxml2 rejects. The tests therefore use well-formed documents
only; `xml-no-xxe.yaml` is a load check (the document declares an entity and still
parses), because whether an entity was resolved is not observable portably.

**Tests.** `tests/engine/body/xml-no-xxe.yaml`, `tests/engine/variables/xml.yaml`

### JSON

**Status:** Core

**Semantics.** Parses the body as JSON. Every scalar leaf (string, number, boolean, null)
becomes an `ARGS_POST` member whose value is the leaf's text, so there are at least as
many members as leaves (subject to `SecArgumentsLimit`). Nesting deeper than
`SecRequestBodyJsonDepthLimit` or a malformed document sets `REQBODY_ERROR` and
`REQBODY_ERROR_MSG`. **The member names are not specified** (ADR-0020): rules MUST
target `ARGS`/`ARGS_POST` as a whole or match `ARGS_NAMES` with an expression anchored at
the end of the name.

**Divergence notes.** The three engines name the same leaf differently: ModSecurity v2
uses the bare key path and repeats an array's key for its elements (`b.c`, `d.d`;
top-level arrays under `array.array`; `apache2/msc_json.c`); libmodsecurity v3 prefixes
every name with `json.` and names array elements `array_N` (`json.b.c`,
`json.d.array_0`; `src/request_body_processor/json.h`, `getCurrentKey`, and `json.cc`);
Coraza prefixes every name with `json.` and numbers array elements (`json.d.0`;
`internal/bodyprocessors/json.go`, `readItems`). See the table in ADR-0020. Coraza also
adds one member per array holding the array's length (`json.d` = `2`), so its member count
exceeds the leaf count; the Core test asserts a lower bound.

**Tests.** `tests/engine/body/json-args.yaml`,
`tests/engine/directives/secrequestbodyjsondepthlimit.yaml`

### RAW

**Status:** Engine-specific

**Semantics.** Coraza only (`internal/bodyprocessors/raw.go`, Coraza ADR-0010): exposes any
body as `REQUEST_BODY` without parsing, selected with `ctl:requestBodyProcessor=RAW`.
The portable equivalent is `ctl:forceRequestBodyVariable=On`.

### Response body processors

**Status:** Engine-specific

**Semantics.** Coraza only: `ctl:responseBodyProcessor=JSON|XML|…` runs a processor over
the response body and fills `RESPONSE_ARGS`, `RESPONSE_XML` and `RES_BODY_*`
(`05-variables.md`). ModSecurity exposes the response only as `RESPONSE_BODY`.
