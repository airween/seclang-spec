# 05. Variables

Variables are what rules inspect. A *collection* has named members (`ARGS:foo`); a
*scalar* has one value. Selectors, counting (`&`) and exclusion (`!`) are defined in
`02-grammar.md#variable-list`; when each variable becomes available is defined by the
phases in `03-processing-model.md#phases`. The index lists every variable name known to
any surveyed engine with its status (`00-conventions.md`).

## Index

| Variable | Status | v2 | v3 | Coraza | Purpose |
|---|---|---|---|---|---|
| [ARGS](#args) | Core | yes | yes | yes | All request arguments (GET and POST) |
| [ARGS_COMBINED_SIZE](#args_combined_size) | Core | yes | yes | yes | Total bytes of argument names and values |
| [ARGS_GET](#args_get) | Core | yes | yes | yes | Query-string arguments |
| [ARGS_GET_NAMES](#args_get_names) | Core | yes | yes | yes | Names of query-string arguments |
| [ARGS_NAMES](#args_names) | Core | yes | yes | yes | Names of all arguments |
| [ARGS_PATH](#args_path) | Engine-specific | - | - | yes | Coraza: arguments extracted from the path by restpath |
| [ARGS_POST](#args_post) | Core | yes | yes | yes | Request-body arguments |
| [ARGS_POST_NAMES](#args_post_names) | Core | yes | yes | yes | Names of request-body arguments |
| [ARGUMENTS_LIMIT_REACHED](#arguments_limit_reached) | Engine-specific | - | - | yes | Coraza: 1 when SecArgumentsLimit truncated ARGS |
| [AUTH_TYPE](#auth_type) | Extended | yes | yes | - | HTTP authentication scheme |
| [DURATION](#duration) | Extended | yes | yes | yes | Time spent in the transaction |
| [ENV](#env) | Extended | yes | yes | yes | Process environment variables |
| [FILES](#files) | Core | yes | yes | yes | Uploaded file names, keyed by field |
| [FILES_COMBINED_SIZE](#files_combined_size) | Core | yes | yes | yes | Total size of uploaded files |
| [FILES_NAMES](#files_names) | Core | yes | yes | yes | Form field names that carried files |
| [FILES_SIZES](#files_sizes) | Extended | yes | yes | yes | Sizes of uploaded files |
| [FILES_TMP_CONTENT](#files_tmp_content) | Extended | yes | yes | yes | Content of uploaded files |
| [FILES_TMPNAMES](#files_tmpnames) | Extended | yes | yes | yes | Temporary file paths of uploads |
| [FULL_REQUEST](#full_request) | Extended | yes | yes | - | Complete request as received |
| [FULL_REQUEST_LENGTH](#full_request_length) | Extended | yes | yes | yes | Length of the complete request |
| [GEO](#geo) | Extended | yes | yes | yes | GeoIP lookup results |
| [GLOBAL](#global) | Extended | yes | yes | - | Persistent collection shared by all transactions |
| [HIGHEST_SEVERITY](#highest_severity) | Extended | yes | yes | yes | Most severe matched rule so far |
| [INBOUND_DATA_ERROR](#inbound_data_error) | Core | yes | yes | yes | 1 when the request body exceeded a limit |
| [IP](#ip) | Extended | yes | yes | - | Persistent collection keyed by client address |
| [JSON](#json) | Engine-specific | - | - | yes | Coraza: parsed JSON body |
| [MATCHED_VAR](#matched_var) | Core | yes | yes | yes | Value of the last matched variable |
| [MATCHED_VAR_NAME](#matched_var_name) | Core | yes | yes | yes | Name of the last matched variable |
| [MATCHED_VARS](#matched_vars) | Core | yes | yes | yes | Values of all variables matched by the last rule |
| [MATCHED_VARS_NAMES](#matched_vars_names) | Extended | yes | yes | yes | Names of all variables matched by the last rule |
| [MODSEC_BUILD](#modsec_build) | Extended | yes | yes | - | Engine build number |
| [MSC_PCRE_ERROR](#msc_pcre_error) | Engine-specific | - | yes | - | v3: 1 on a PCRE error |
| [MSC_PCRE_LIMITS_EXCEEDED](#msc_pcre_limits_exceeded) | Engine-specific | - | yes | - | v3: 1 when PCRE limits were hit |
| [MULTIPART_BOUNDARY_QUOTED](#multipart_boundary_quoted) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_BOUNDARY_WHITESPACE](#multipart_boundary_whitespace) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_CRLF_LF_LINES](#multipart_crlf_lf_lines) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_CRLF_LINE](#multipart_crlf_line) | Deprecated | yes | - | - | Multipart anomaly flag |
| [MULTIPART_DATA_AFTER](#multipart_data_after) | Extended | yes | yes | yes | Multipart anomaly flag |
| [MULTIPART_DATA_BEFORE](#multipart_data_before) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_DUPLICATE_PART_HEADER](#multipart_duplicate_part_header) | Engine-specific | - | yes | yes | v3, Coraza: multipart anomaly flag |
| [MULTIPART_FILE_LIMIT_EXCEEDED](#multipart_file_limit_exceeded) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_FILENAME](#multipart_filename) | Extended | yes | yes | yes | File name of the current part |
| [MULTIPART_FILENAME_CHARSET](#multipart_filename_charset) | Engine-specific | - | yes | yes | v3, Coraza: RFC 5987 filename* charset |
| [MULTIPART_FILENAME_LANGUAGE](#multipart_filename_language) | Engine-specific | - | yes | yes | v3, Coraza: RFC 5987 filename* language |
| [MULTIPART_HEADER_FOLDING](#multipart_header_folding) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_INVALID_HEADER_FOLDING](#multipart_invalid_header_folding) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_INVALID_PART](#multipart_invalid_part) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_INVALID_QUOTING](#multipart_invalid_quoting) | Extended | yes | yes | yes | Multipart anomaly flag |
| [MULTIPART_LF_LINE](#multipart_lf_line) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_MISSING_SEMICOLON](#multipart_missing_semicolon) | Extended | yes | yes | - | Multipart anomaly flag |
| [MULTIPART_NAME](#multipart_name) | Extended | yes | yes | yes | Field name of the current part |
| [MULTIPART_PART_HEADERS](#multipart_part_headers) | Core | yes | yes | yes | Raw headers of each multipart part |
| [MULTIPART_STRICT_ERROR](#multipart_strict_error) | Core | yes | yes | yes | 1 on any multipart parsing anomaly |
| [MULTIPART_UNMATCHED_BOUNDARY](#multipart_unmatched_boundary) | Extended | yes | yes | - | Multipart anomaly flag |
| [OUTBOUND_DATA_ERROR](#outbound_data_error) | Core | yes | yes | yes | 1 when the response body exceeded a limit |
| [PATH_INFO](#path_info) | Extended | yes | yes | - | Extra path after the script |
| [PERF_ALL](#perf_all) | Deprecated | yes | - | - | Timing |
| [PERF_COMBINED](#perf_combined) | Deprecated | yes | - | - | Timing |
| [PERF_GC](#perf_gc) | Deprecated | yes | - | - | Timing |
| [PERF_LOGGING](#perf_logging) | Deprecated | yes | - | - | Timing |
| [PERF_PHASE1](#perf_phase1) | Deprecated | yes | - | - | Timing |
| [PERF_PHASE2](#perf_phase2) | Deprecated | yes | - | - | Timing |
| [PERF_PHASE3](#perf_phase3) | Deprecated | yes | - | - | Timing |
| [PERF_PHASE4](#perf_phase4) | Deprecated | yes | - | - | Timing |
| [PERF_PHASE5](#perf_phase5) | Deprecated | yes | - | - | Timing |
| [PERF_RULES](#perf_rules) | Deprecated | yes | - | - | Timing per rule |
| [PERF_SREAD](#perf_sread) | Deprecated | yes | - | - | Timing |
| [PERF_SWRITE](#perf_swrite) | Deprecated | yes | - | - | Timing |
| [QUERY_STRING](#query_string) | Core | yes | yes | yes | Raw query string |
| [REMOTE_ADDR](#remote_addr) | Core | yes | yes | yes | Client IP address |
| [REMOTE_HOST](#remote_host) | Extended | yes | yes | yes | Client host name |
| [REMOTE_PORT](#remote_port) | Extended | yes | yes | yes | Client port |
| [REMOTE_USER](#remote_user) | Extended | yes | yes | - | Authenticated user |
| [REQBODY_ERROR](#reqbody_error) | Core | yes | yes | yes | 1 when the body processor failed |
| [REQBODY_ERROR_MSG](#reqbody_error_msg) | Core | yes | yes | yes | Body processor error message |
| [REQBODY_PROCESSOR](#reqbody_processor) | Core | yes | yes | yes | Body processor in use |
| [REQBODY_PROCESSOR_ERROR](#reqbody_processor_error) | Extended | - | yes | yes | Older name for REQBODY_ERROR |
| [REQBODY_PROCESSOR_ERROR_MSG](#reqbody_processor_error_msg) | Extended | - | yes | yes | Older name for REQBODY_ERROR_MSG |
| [REQUEST_BASENAME](#request_basename) | Core | yes | yes | yes | Last path segment |
| [REQUEST_BODY](#request_body) | Core | yes | yes | yes | Raw request body |
| [REQUEST_BODY_LENGTH](#request_body_length) | Core | yes | yes | yes | Request body size in bytes |
| [REQUEST_COOKIES](#request_cookies) | Core | yes | yes | yes | Cookies by name |
| [REQUEST_COOKIES_NAMES](#request_cookies_names) | Core | yes | yes | yes | Cookie names |
| [REQUEST_FILENAME](#request_filename) | Core | yes | yes | yes | Request path without query |
| [REQUEST_HEADERS](#request_headers) | Core | yes | yes | yes | Request headers by name |
| [REQUEST_HEADERS_NAMES](#request_headers_names) | Core | yes | yes | yes | Request header names |
| [REQUEST_LINE](#request_line) | Core | yes | yes | yes | The request line |
| [REQUEST_METHOD](#request_method) | Core | yes | yes | yes | HTTP method |
| [REQUEST_PROTOCOL](#request_protocol) | Core | yes | yes | yes | HTTP version |
| [REQUEST_URI](#request_uri) | Core | yes | yes | yes | Path and query |
| [REQUEST_URI_RAW](#request_uri_raw) | Core | yes | yes | yes | URI exactly as sent |
| [REQUEST_XML](#request_xml) | Engine-specific | - | - | yes | Coraza: alias of XML |
| [RES_BODY_ERROR](#res_body_error) | Engine-specific | - | - | yes | Coraza: response body processor error flag |
| [RES_BODY_ERROR_MSG](#res_body_error_msg) | Engine-specific | - | - | yes | Coraza: response body processor error message |
| [RES_BODY_PROCESSOR](#res_body_processor) | Engine-specific | - | - | yes | Coraza: response body processor |
| [RES_BODY_PROCESSOR_ERROR](#res_body_processor_error) | Engine-specific | - | - | yes | Coraza: response body processor error |
| [RES_BODY_PROCESSOR_ERROR_MSG](#res_body_processor_error_msg) | Engine-specific | - | - | yes | Coraza: response body processor error message |
| [RESOURCE](#resource) | Extended | yes | yes | - | Persistent collection keyed by resource |
| [RESPONSE_ARGS](#response_args) | Engine-specific | - | - | yes | Coraza: arguments parsed from the response |
| [RESPONSE_BODY](#response_body) | Core | yes | yes | yes | Response body |
| [RESPONSE_CONTENT_LENGTH](#response_content_length) | Extended | yes | yes | yes | Response Content-Length |
| [RESPONSE_CONTENT_TYPE](#response_content_type) | Extended | yes | yes | yes | Response Content-Type |
| [RESPONSE_HEADERS](#response_headers) | Core | yes | yes | yes | Response headers by name |
| [RESPONSE_HEADERS_NAMES](#response_headers_names) | Extended | yes | yes | yes | Response header names |
| [RESPONSE_PROTOCOL](#response_protocol) | Extended | yes | yes | yes | Response HTTP version |
| [RESPONSE_STATUS](#response_status) | Core | yes | yes | yes | Response status code |
| [RESPONSE_XML](#response_xml) | Engine-specific | - | - | yes | Coraza: parsed XML response |
| [RULE](#rule) | Extended | yes | yes | yes | Metadata of the current rule |
| [SCRIPT_BASENAME](#script_basename) | Deprecated | yes | - | - | Script base name |
| [SCRIPT_FILENAME](#script_filename) | Deprecated | yes | - | - | Script path |
| [SCRIPT_GID](#script_gid) | Deprecated | yes | - | - | Script group id |
| [SCRIPT_GROUPNAME](#script_groupname) | Deprecated | yes | - | - | Script group name |
| [SCRIPT_MODE](#script_mode) | Deprecated | yes | - | - | Script permissions |
| [SCRIPT_UID](#script_uid) | Deprecated | yes | - | - | Script owner id |
| [SCRIPT_USERNAME](#script_username) | Deprecated | yes | - | - | Script owner name |
| [SDBM_DELETE_ERROR](#sdbm_delete_error) | Deprecated | yes | - | - | SDBM delete failure flag |
| [SERVER_ADDR](#server_addr) | Extended | yes | yes | yes | Server IP address |
| [SERVER_NAME](#server_name) | Extended | yes | yes | yes | Server host name |
| [SERVER_PORT](#server_port) | Extended | yes | yes | yes | Server port |
| [SESSION](#session) | Extended | yes | yes | - | Persistent collection keyed by session id |
| [SESSIONID](#sessionid) | Extended | yes | yes | - | Session id set by setsid |
| [STATUS](#status) | Engine-specific | - | yes | - | v3: response status |
| [STATUS_LINE](#status_line) | Extended | yes | - | yes | Response status line |
| [STREAM_INPUT_BODY](#stream_input_body) | Deprecated | yes | - | - | Writable raw request body |
| [STREAM_OUTPUT_BODY](#stream_output_body) | Deprecated | yes | - | - | Writable raw response body |
| [TIME](#time) | Extended | yes | yes | yes | Current time hh:mm:ss |
| [TIME_DAY](#time_day) | Extended | yes | yes | yes | Day of month |
| [TIME_EPOCH](#time_epoch) | Extended | yes | yes | yes | Seconds since the epoch |
| [TIME_HOUR](#time_hour) | Extended | yes | yes | yes | Hour |
| [TIME_MIN](#time_min) | Extended | yes | yes | yes | Minute |
| [TIME_MON](#time_mon) | Extended | yes | yes | yes | Month |
| [TIME_SEC](#time_sec) | Extended | yes | yes | yes | Second |
| [TIME_WDAY](#time_wday) | Extended | yes | yes | yes | Weekday |
| [TIME_YEAR](#time_year) | Extended | yes | yes | yes | Year |
| [TX](#tx) | Core | yes | yes | yes | Per-transaction read-write collection |
| [UNIQUE_ID](#unique_id) | Core | yes | yes | yes | Transaction identifier |
| [URI_PARSE_ERROR](#uri_parse_error) | Engine-specific | - | - | yes | Coraza: 1 when the URI failed to parse |
| [URLENCODED_ERROR](#urlencoded_error) | Extended | yes | yes | yes | 1 on invalid URL encoding in arguments |
| [USER](#user) | Extended | yes | yes | - | Persistent collection keyed by user id |
| [USERAGENT_IP](#useragent_ip) | Deprecated | yes | - | - | Client address from a proxy header |
| [USERID](#userid) | Extended | yes | yes | - | User id set by setuid |
| [WEBAPPID](#webappid) | Extended | yes | yes | - | Application id |
| [WEBSERVER_ERROR_LOG](#webserver_error_log) | Deprecated | yes | - | - | Messages the host wrote to its error log |
| [XML](#xml) | Core | yes | yes | yes | XML body selectors |

## Collections and keys

### Collection keys

**Status:** Core

**Syntax.** `COLLECTION:key`, `COLLECTION:/regex/`, `&COLLECTION`, `!COLLECTION:key`
(`02-grammar.md#variable-list`).

**Semantics.** A *collection* holds zero or more members, each with a name and a value; a
*scalar* variable holds exactly one value and takes no selector: the empty string until the
engine sets it (`REQBODY_PROCESSOR` before a body is processed, `RESPONSE_BODY` when the
response is not inspected), so a negated operator on an unset scalar matches and `&` counts
1 (ADR-0037). Member names are matched against a
`key` selector **case-insensitively** in every collection, `TX` included (ADR-0008); a
regex selector is applied to the name unanchored and **case-insensitively** too, so
`TX:/^SCORE$/` selects a member written as `tx.score`. Names that differ only in case
denote the same member wherever a name is written (`setvar`, macros, selectors). Members
keep the order in which the engine parsed them; a repeated name yields repeated members,
so `&ARGS:a` can be greater than 1. The case in which an engine reports a member's name
(`MATCHED_VAR_NAME`, `*_NAMES` collections, macros expanding them) is **not specified**.

**Divergence notes.** ModSecurity v2 (`apache2/re_variables.c`, `strcasecmp`) and
libmodsecurity v3 (`headers/modsecurity/anchored_set_variable.h`, `MyEqual`/`MyHash` lower
case) match keys case-insensitively. Coraza 3.8.1 does too by default
(`internal/collections/map.go`, `strings.ToLower`) but a build with
`coraza.rule.case_sensitive_args_keys` (Coraza ADR-0016) is case-sensitive and therefore
non-conforming. Regex selectors: v2 compiles them with `PCRE2_CASELESS`
(`apache2/re_variables.c`, `var_generic_list_validate`), libmodsecurity v3 with
`ignoreCase` (`src/variables/variable.h`, `VariableRegex` builds `m_r(regex, true)`), and Coraza lower-cases both the pattern and the stored names
(`internal/corazawaf/rule.go`, `AddVariable`), which also turns escapes such as `\D`, `\S`
and `\W` into `\d`, `\s` and `\w`; a portable selector does not use upper-case escapes.
For the `ARGS` family Coraza keeps the pattern as written (`caseSensitiveVariable`) while
storing the names lower-cased, so an upper-case pattern never matches an argument
(`key-case-args-regex.yaml` fails on Coraza, `compat/known-gaps.md`).
Reported names: v2 and v3 keep the first spelling written (`TX:Foo`), Coraza the
lower-cased one (`TX:foo`). See ADR-0008. All three engines yield the empty string for an unset `REQBODY_PROCESSOR`
(v2 `apache2/re_variables.c`, `var_reqbody_processor_generate`; libmodsecurity v3
`src/anchored_variable.cc`, `AnchoredVariable::evaluate` always pushes its value; Coraza
`collections.Single`). Other v2 generators `return 0` when their datum is `NULL` and so
yield no value; no test observes one yet.

**Tests.** `tests/engine/variables/key-case.yaml`, `tests/engine/variables/key-case-args-regex.yaml`, `tests/engine/variables/scalar-unset.yaml`

### Persistent collections

**Status:** Extended

**Syntax.** `IP`, `SESSION`, `USER`, `GLOBAL`, `RESOURCE` collections; `SESSIONID`,
`USERID`, `WEBAPPID` scalars; the actions `initcol`, `setsid`, `setuid`, `setrsc`,
`expirevar` on them; directives `SecDataDir`, `SecCollectionTimeout`, `SecWebAppId`.

**Semantics.** State that survives a transaction, keyed by an address, a session id, a
user id, a resource path, or shared globally, with per-variable expiry. Specified by the
ModSecurity reference manual; this document defines the feature id
`05-variables.md#persistent-collections` that engine-tier profiles name in `requires:`.
Full semantics are deferred until two engines implement them.

**Divergence notes.** ModSecurity v2 implements them on SDBM files, libmodsecurity v3 in
memory per process (optionally LMDB), Coraza not at all. See ADR-0007.

**Tests.** `tests/engine/variables/persistent-collections.yaml` (Extended; `requires:`)

## Request arguments

### ARGS

**Status:** Core

**Semantics.** Collection of every request argument: `ARGS_GET` followed by `ARGS_POST`.
Each member's name is the argument name after URL decoding and its value the argument
value after URL decoding (`+` as space). Repeated names yield repeated members. The
number of members never exceeds `SecArgumentsLimit`.

**Divergence notes.** Coraza also places the leaves of a JSON body into `ARGS_POST` as
`json.path.to.key` when the `JSON` processor runs (Engine-specific).

**Tests.** `tests/engine/variables/args.yaml`

### ARGS_COMBINED_SIZE

**Status:** Core

**Semantics.** Scalar: the sum of the lengths, in bytes after URL decoding, of every
`ARGS` member name and value.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/args.yaml`

### ARGS_GET

**Status:** Core

**Semantics.** Collection of the arguments parsed from the query string, available from
phase 1. Separator per `SecArgumentSeparator`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/args.yaml`

### ARGS_GET_NAMES

**Status:** Core

**Semantics.** Collection whose members' values are the names of `ARGS_GET`, in order,
repeated when the argument repeats.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/args.yaml`

### ARGS_NAMES

**Status:** Core

**Semantics.** Collection whose members' values are the names of `ARGS`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/args.yaml`

### ARGS_POST

**Status:** Core

**Semantics.** Collection of the arguments parsed from the request body by the
`URLENCODED` and `MULTIPART` body processors (non-file fields). Empty until phase 2 and
when `SecRequestBodyAccess` is `Off`.

**Divergence notes.** JSON leaves in Coraza (see `ARGS`); `SecParseXmlIntoArgs`
(Extended) adds XML values in ModSecurity.

**Tests.** `tests/engine/variables/args.yaml`

### ARGS_POST_NAMES

**Status:** Core

**Semantics.** Collection whose members' values are the names of `ARGS_POST`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/args.yaml`

## Request line and headers

### QUERY_STRING

**Status:** Core

**Semantics.** Scalar: the part of the request URI after the first `?`, as sent, without
decoding; empty when there is no `?`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-line.yaml`

### REMOTE_ADDR

**Status:** Core

**Semantics.** Scalar: the client IP address of the connection, as a textual IPv4 or IPv6
address. Engines behind proxies MAY be configured to use a forwarded address; that is an
integration concern outside this specification.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/remote-addr-unique-id.yaml`

### REQUEST_BASENAME

**Status:** Core

**Semantics.** Scalar: the last segment of `REQUEST_FILENAME`, after the final `/`; the
whole filename when there is no `/`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-line.yaml`

### REQUEST_COOKIES

**Status:** Core

**Semantics.** Collection of the cookies in every `Cookie` request header, split on `;`,
each member named by the cookie name and valued by the cookie value, both with
surrounding whitespace removed and **not** URL-decoded. A repeated name yields repeated
members.

**Divergence notes.** None known for format 0 cookies (`SecCookieFormat`).

**Tests.** `tests/engine/variables/request-cookies.yaml`

### REQUEST_COOKIES_NAMES

**Status:** Core

**Semantics.** Collection whose members' values are the names of `REQUEST_COOKIES`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-cookies.yaml`

### REQUEST_FILENAME

**Status:** Core

**Semantics.** Scalar: the path component of the request URI without the query string.
Whether percent-encoded characters in the path are decoded is **not specified**; the
test uses a path with none.

**Divergence notes.** ModSecurity v2 uses Apache's `parsed_uri.path`, which is the path as
sent (`apache2/re_variables.c`); libmodsecurity v3 (`src/transaction.cc`, `m_uri_decoded`)
and Coraza (`transaction.go`, `url.Parse` path) use the decoded path.

**Tests.** `tests/engine/variables/request-line.yaml`

### REQUEST_HEADERS

**Status:** Core

**Semantics.** Collection of request headers, one member per header line, named by the
header name (matched case-insensitively) and valued by the header value with
surrounding whitespace removed. Repeated headers yield repeated members.

**Divergence notes.** The case in which engines report header names in
`REQUEST_HEADERS_NAMES` and `MATCHED_VAR_NAME` differs (Coraza lower-cases, ModSecurity
keeps the case as sent); tests compare names case-insensitively.

**Tests.** `tests/engine/variables/request-headers.yaml`

### REQUEST_HEADERS_NAMES

**Status:** Core

**Semantics.** Collection whose members' values are the names of `REQUEST_HEADERS`.

**Divergence notes.** Name case as above.

**Tests.** `tests/engine/variables/request-headers.yaml`

### REQUEST_LINE

**Status:** Core

**Semantics.** Scalar: the request line as received, `METHOD SP REQUEST-URI SP
PROTOCOL`, without the line terminator.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-line.yaml`

### REQUEST_METHOD

**Status:** Core

**Semantics.** Scalar: the request method, case preserved.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-line.yaml`

### REQUEST_PROTOCOL

**Status:** Core

**Semantics.** Scalar: the protocol token of the request line, e.g. `HTTP/1.1`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-line.yaml`

### REQUEST_URI

**Status:** Core

**Semantics.** Scalar: the request path followed by `?` and the query string when
present, without scheme and host, as sent (no decoding).

**Divergence notes.** Coraza re-serialises the parsed URL (`transaction.go`,
`url.URL.String()`), which can normalise unusual encodings; identical for the
origin-form requests the tests use.

**Tests.** `tests/engine/variables/request-line.yaml`

### REQUEST_URI_RAW

**Status:** Core

**Semantics.** Scalar: the request target exactly as it appeared in the request line,
including scheme and host for absolute-form requests.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-line.yaml`

### UNIQUE_ID

**Status:** Core

**Semantics.** Scalar: an opaque, non-empty identifier unique to the transaction, suitable
for correlating log entries. Its format is engine-specific.

**Divergence notes.** ModSecurity v2 uses Apache's `mod_unique_id` value; libmodsecurity
v3 a SHA-1 hex digest or a timestamp-and-counter string (`src/unique_id.cc`,
`src/transaction.cc`); Coraza a random 19-character string (`waf.go`,
`stringutils.RandomString(19)`).

**Tests.** `tests/engine/variables/remote-addr-unique-id.yaml`

## Request body

### FILES

**Status:** Core

**Semantics.** Collection of uploaded files in a `multipart/form-data` body, one member
per file part, named by the form field name and valued by the original file name from
`Content-Disposition`.

**Divergence notes.** Coraza 3.8.1 stores every member under the empty name
(`internal/bodyprocessors/multipart.go`, `filesCol.Add("", filename)`), so `FILES:field`
selects nothing there (`compat/known-gaps.md`); `FILES` as a whole works everywhere.

**Tests.** `tests/engine/variables/multipart.yaml`

### FILES_COMBINED_SIZE

**Status:** Core

**Semantics.** Scalar: the total size in bytes of all uploaded file contents; form fields
of the same body do not count.

**Divergence notes.** Coraza adds the bytes of non-file fields as well
(`internal/bodyprocessors/multipart.go`, `totalSize` in the field branch); ModSecurity v2
(`apache2/re_variables.c`, `MULTIPART_FILE` parts only) and libmodsecurity v3 count files.
`files-combined-size-fields.yaml` fails on Coraza (`compat/known-gaps.md`).

**Tests.** `tests/engine/body/files-combined-size-fields.yaml`

**Divergence notes.** Coraza 3.8.1 also counts the bytes of non-file fields
(`multipart.go`, `totalSize += len(data)`); the Core test has no non-file field.

**Tests.** `tests/engine/variables/multipart.yaml`

### FILES_NAMES

**Status:** Core

**Semantics.** Collection whose members' values are the form field names of `FILES`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/multipart.yaml`

### INBOUND_DATA_ERROR

**Status:** Core

**Semantics.** Scalar: `1` when the request body exceeded `SecRequestBodyLimit` under
`ProcessPartial` (and, in libmodsecurity v3, `SecRequestBodyNoFilesLimit`), otherwise
`0` or empty. Available from phase 2.

**Divergence notes.** See `04-directives.md#secrequestbodynofileslimit`.

**Tests.** `tests/engine/directives/secrequestbodylimit-processpartial.yaml`

### MULTIPART_PART_HEADERS

**Status:** Core

**Semantics.** Collection with one member per multipart part, named by the part's field
name and valued by the raw header block of that part.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/multipart.yaml`

### MULTIPART_STRICT_ERROR

**Status:** Core

**Semantics.** Scalar: `1` when the multipart parser detected any anomaly (unmatched or
malformed boundary, data before or after the body, invalid quoting, header folding, bare
LF line endings on boundary or header lines, missing semicolons, invalid parts, file limit exceeded), otherwise `0`.
Which anomalies an engine detects differs, so this specification only requires `0` for a
well-formed body; the individual `MULTIPART_*` flags are Extended.

**Divergence notes.** Coraza ADR-0017 lists the anomalies it detects.

**Tests.** `tests/engine/variables/multipart.yaml`

### REQBODY_ERROR

**Status:** Core

**Semantics.** Scalar: `1` when the body processor failed to parse the request body
(malformed urlencoded, multipart, XML or JSON, or a depth or size limit), otherwise `0`.
Rules in phase 2 decide what to do, as the recommended configurations' rule 200002 does.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/body-errors.yaml`

### REQBODY_ERROR_MSG

**Status:** Core

**Semantics.** Scalar: a human-readable description of the `REQBODY_ERROR` failure;
empty when there was none. Wording is engine-specific.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/body-errors.yaml`

### REQBODY_PROCESSOR

**Status:** Core

**Semantics.** Scalar: the name of the body processor used, one of `URLENCODED`,
`MULTIPART`, `XML`, `JSON`. `ctl:requestBodyProcessor` sets it at once, whether or not
the request has a body (ModSecurity v2 `apache2/re_actions.c`, libmodsecurity v3
`src/actions/ctl/request_body_processor_json.cc`, Coraza `internal/actions/ctl.go`);
selection from the `Content-Type` header sets it only when a body was processed, so it
is empty for a bodiless request without the `ctl`.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-body.yaml`

**Tests.** `tests/engine/variables/request-body.yaml`

### REQUEST_BODY

**Status:** Core

**Semantics.** Scalar: the raw request body when `SecRequestBodyAccess` is `On` and the
processor is `URLENCODED`, or when `ctl:forceRequestBodyVariable=On` was set in phase 1.
In every other case, including `MULTIPART` bodies, its value is **not specified**
(ADR-0022); use `FILES*` and `ARGS_POST` for multipart content.

**Divergence notes.** Without a processor the variable is absent in ModSecurity v2,
holds the raw body in libmodsecurity v3 (also for multipart) and is empty in Coraza.
See ADR-0022.

**Tests.** `tests/engine/variables/request-body.yaml`

### REQUEST_BODY_LENGTH

**Status:** Core

**Semantics.** Scalar: the number of request body bytes received, as a decimal string.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/request-body.yaml`

### XML

**Status:** Core

**Semantics.** Collection available when the `XML` body processor ran. Two selectors are
Core: `XML:/*` yields the document's text content (as one value from the root element in
libxml2-based engines, as one value per non-blank text node in Coraza; rules MUST NOT
depend on the split), and `XML://@*` yields the value of every attribute. Any other XPath
expression is Extended.

**Divergence notes.** ModSecurity v2 and libmodsecurity v3 evaluate arbitrary XPath with
libxml2 (`src/variables/xml.cc`); Coraza (`internal/bodyprocessors/xml.go`) implements
exactly the two Core selectors.

**Tests.** `tests/engine/variables/xml.yaml`

## Matching state

### MATCHED_VAR

**Status:** Core

**Semantics.** Scalar: the value of the most recently matched variable, **after**
transformations, available to the rest of the same rule and chain (`setvar`, `logdata`,
chain members). Its value in later rules is **not specified**.

**Divergence notes.** ModSecurity v2 keeps it until the next match; libmodsecurity v3
clears it after every rule (`src/rules_set.cc`, `cleanMatchedVars`); Coraza keeps
`MATCHED_VAR` but resets `MATCHED_VARS` before each rule.

**Tests.** `tests/engine/variables/matched-vars.yaml`

### MATCHED_VAR_NAME

**Status:** Core

**Semantics.** Scalar: the full name (`COLLECTION:key`) of the most recently matched
variable.

**Divergence notes.** Header-name case as noted under `REQUEST_HEADERS`.

**Tests.** `tests/engine/variables/matched-vars.yaml`

### MATCHED_VARS

**Status:** Core

**Semantics.** Collection of every variable value that matched in the current rule (an
operator may match several members), after transformations; available to chain members
and the rule's own actions. Its contents in later rules are **not specified**.

**Divergence notes.** As `MATCHED_VAR`.

**Tests.** `tests/engine/variables/matched-vars.yaml`

### TX

**Status:** Core

**Semantics.** Per-transaction read-write collection. Members are created and changed by
`setvar`, read by rules and macros, and discarded at the end of the transaction. `TX:0`
to `TX:9` receive the full match and capture groups of the last operator that ran with
`capture`. Names are case-insensitive (`#collection-keys`); CRS stores every anomaly
score here.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/tx-and-capture.yaml`

## Response

### OUTBOUND_DATA_ERROR

**Status:** Core

**Semantics.** Scalar: `1` when the response body exceeded `SecResponseBodyLimit` under
`ProcessPartial`. Available from phase 4.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/secresponsebodylimit-processpartial.yaml`

### RESPONSE_BODY

**Status:** Core

**Semantics.** Scalar: the response body, when `SecResponseBodyAccess` is `On` and the
response `Content-Type` is listed by `SecResponseBodyMimeType`. Available in phase 4.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/response.yaml`

### RESPONSE_HEADERS

**Status:** Core

**Semantics.** Collection of response headers, like `REQUEST_HEADERS`. Available from
phase 3.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/response.yaml`

### RESPONSE_STATUS

**Status:** Core

**Semantics.** Scalar: the response status code as a decimal string. Available from
phase 3.

**Divergence notes.** None known.

**Tests.** `tests/engine/variables/response.yaml`

## Extended variables

Specified in outline; SHOULD be implemented. Full sections follow when an engine test can be written for each.

### AUTH_TYPE

**Status:** Extended

**Semantics.** HTTP authentication scheme.

**Implemented by.** v2, v3.

### DURATION

**Status:** Extended

**Semantics.** The wall-clock time elapsed since the engine created the transaction, in whole microseconds, as a base-10 integer (truncated). Time the host spent before handing the request to the engine, such as reading the request headers, is not counted (ADR-0019).

**Divergence notes.** ModSecurity v2 reports wall-clock microseconds since the host's `r->request_time` (`apache2/re_variables.c`, `var_duration_generate`), which on Apache is set after the request line and before the headers are read; libmodsecurity v3 reports process CPU seconds as a decimal fraction (`src/variables/duration.cc`, `utils::cpu_seconds()`); Coraza always reports `0` (`internal/corazawaf/waf.go`).

**Tests.** `tests/engine/variables/duration.yaml`

**Implemented by.** v2, v3, Coraza.

### ENV

**Status:** Extended

**Semantics.** Process environment variables.

**Implemented by.** v2, v3, Coraza.

### FILES_SIZES

**Status:** Extended

**Semantics.** Sizes of uploaded files.

**Implemented by.** v2, v3, Coraza.

### FILES_TMP_CONTENT

**Status:** Extended

**Semantics.** Content of uploaded files.

**Implemented by.** v2, v3, Coraza.

### FILES_TMPNAMES

**Status:** Extended

**Semantics.** Temporary file paths of uploads.

**Implemented by.** v2, v3, Coraza.

### FULL_REQUEST

**Status:** Extended

**Semantics.** Complete request as received.

**Implemented by.** v2, v3.

### FULL_REQUEST_LENGTH

**Status:** Extended

**Semantics.** Length of the complete request.

**Implemented by.** v2, v3, Coraza.

### GEO

**Status:** Extended

**Semantics.** GeoIP lookup results.

**Implemented by.** v2, v3, Coraza.

### GLOBAL

**Status:** Extended

**Semantics.** Persistent collection shared by all transactions. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### HIGHEST_SEVERITY

**Status:** Extended

**Semantics.** The numerically lowest `severity` among matched rules so far, 255 when none.

**Implemented by.** v2, v3, Coraza.

### IP

**Status:** Extended

**Semantics.** Persistent collection keyed by client address. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### MATCHED_VARS_NAMES

**Status:** Extended

**Semantics.** Names of all variables matched by the last rule.

**Implemented by.** v2, v3, Coraza.

### MODSEC_BUILD

**Status:** Extended

**Semantics.** Engine build number.

**Implemented by.** v2, v3.

### MULTIPART_BOUNDARY_QUOTED

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_BOUNDARY_WHITESPACE

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_CRLF_LF_LINES

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_DATA_AFTER

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3, Coraza.

### MULTIPART_DATA_BEFORE

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_FILE_LIMIT_EXCEEDED

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_FILENAME

**Status:** Extended

**Semantics.** File name of the current part.

**Implemented by.** v2, v3, Coraza.

### MULTIPART_HEADER_FOLDING

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_INVALID_HEADER_FOLDING

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_INVALID_PART

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_INVALID_QUOTING

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3, Coraza.

### MULTIPART_LF_LINE

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_MISSING_SEMICOLON

**Status:** Extended

**Semantics.** Multipart anomaly flag.

**Implemented by.** v2, v3.

### MULTIPART_NAME

**Status:** Extended

**Semantics.** Field name of the current part.

**Implemented by.** v2, v3, Coraza.

### MULTIPART_UNMATCHED_BOUNDARY

**Status:** Extended

**Semantics.** `1` when a line looked like a boundary but did not match the declared one. Used by `modsecurity.conf-recommended` rule 200004; Coraza has no such variable and its recommended configuration omits the rule, so this is Extended (ADR-0005).

**Implemented by.** v2, v3.

### PATH_INFO

**Status:** Extended

**Semantics.** Extra path after the script.

**Implemented by.** v2, v3.

### REMOTE_HOST

**Status:** Extended

**Semantics.** Client host name.

**Implemented by.** v2, v3, Coraza.

### REMOTE_PORT

**Status:** Extended

**Semantics.** Client port.

**Implemented by.** v2, v3, Coraza.

### REMOTE_USER

**Status:** Extended

**Semantics.** Authenticated user.

**Implemented by.** v2, v3.

### REQBODY_PROCESSOR_ERROR

**Status:** Extended

**Semantics.** Older name for REQBODY_ERROR.

**Implemented by.** v3, Coraza.

### REQBODY_PROCESSOR_ERROR_MSG

**Status:** Extended

**Semantics.** Older name for REQBODY_ERROR_MSG.

**Implemented by.** v3, Coraza.

### RESOURCE

**Status:** Extended

**Semantics.** Persistent collection keyed by resource. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### RESPONSE_CONTENT_LENGTH

**Status:** Extended

**Semantics.** Response Content-Length.

**Implemented by.** v2, v3, Coraza.

### RESPONSE_CONTENT_TYPE

**Status:** Extended

**Semantics.** Response Content-Type.

**Implemented by.** v2, v3, Coraza.

### RESPONSE_HEADERS_NAMES

**Status:** Extended

**Semantics.** Response header names.

**Implemented by.** v2, v3, Coraza.

### RESPONSE_PROTOCOL

**Status:** Extended

**Semantics.** Response HTTP version.

**Implemented by.** v2, v3, Coraza.

### RULE

**Status:** Extended

**Semantics.** Metadata of the current rule: `RULE:id`, `RULE:msg`, `RULE:rev`, `RULE:severity`, `RULE:logdata`.

**Implemented by.** v2, v3, Coraza.

### SERVER_ADDR

**Status:** Extended

**Semantics.** Server IP address.

**Implemented by.** v2, v3, Coraza.

### SERVER_NAME

**Status:** Extended

**Semantics.** Server host name.

**Implemented by.** v2, v3, Coraza.

### SERVER_PORT

**Status:** Extended

**Semantics.** Server port.

**Implemented by.** v2, v3, Coraza.

### SESSION

**Status:** Extended

**Semantics.** Persistent collection keyed by session id. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### SESSIONID

**Status:** Extended

**Semantics.** Session id set by setsid. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### STATUS_LINE

**Status:** Extended

**Semantics.** Response status line.

**Implemented by.** v2, Coraza.

### TIME

**Status:** Extended

**Semantics.** Current time `hh:mm:ss`; the other `TIME_*` scalars expose its components and `TIME_EPOCH` the Unix time.

**Implemented by.** v2, v3, Coraza.

### TIME_DAY

**Status:** Extended

**Semantics.** Day of month.

**Implemented by.** v2, v3, Coraza.

### TIME_EPOCH

**Status:** Extended

**Semantics.** Seconds since the epoch.

**Implemented by.** v2, v3, Coraza.

### TIME_HOUR

**Status:** Extended

**Semantics.** Hour.

**Implemented by.** v2, v3, Coraza.

### TIME_MIN

**Status:** Extended

**Semantics.** Minute.

**Implemented by.** v2, v3, Coraza.

### TIME_MON

**Status:** Extended

**Semantics.** Month.

**Implemented by.** v2, v3, Coraza.

### TIME_SEC

**Status:** Extended

**Semantics.** Second.

**Implemented by.** v2, v3, Coraza.

### TIME_WDAY

**Status:** Extended

**Semantics.** Weekday.

**Implemented by.** v2, v3, Coraza.

### TIME_YEAR

**Status:** Extended

**Semantics.** Year.

**Implemented by.** v2, v3, Coraza.

### URLENCODED_ERROR

**Status:** Extended

**Semantics.** 1 on invalid URL encoding in arguments.

**Implemented by.** v2, v3, Coraza.

### USER

**Status:** Extended

**Semantics.** Persistent collection keyed by user id. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### USERID

**Status:** Extended

**Semantics.** User id set by setuid. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.

### WEBAPPID

**Status:** Extended

**Semantics.** Application id. Part of `#persistent-collections` (ADR-0007).

**Implemented by.** v2, v3.


## Deprecated variables

ModSecurity v2 only. Engines MUST accept the names in a variable list and MAY return no values (ADR-0011).

### MULTIPART_CRLF_LINE

**Status:** Deprecated

**Semantics.** Multipart anomaly flag. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_ALL

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_COMBINED

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_GC

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_LOGGING

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_PHASE1

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_PHASE2

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_PHASE3

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_PHASE4

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_PHASE5

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_RULES

**Status:** Deprecated

**Semantics.** Timing per rule. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_SREAD

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### PERF_SWRITE

**Status:** Deprecated

**Semantics.** Timing. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_BASENAME

**Status:** Deprecated

**Semantics.** Script base name. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_FILENAME

**Status:** Deprecated

**Semantics.** Script path. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_GID

**Status:** Deprecated

**Semantics.** Script group id. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_GROUPNAME

**Status:** Deprecated

**Semantics.** Script group name. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_MODE

**Status:** Deprecated

**Semantics.** Script permissions. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_UID

**Status:** Deprecated

**Semantics.** Script owner id. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SCRIPT_USERNAME

**Status:** Deprecated

**Semantics.** Script owner name. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### SDBM_DELETE_ERROR

**Status:** Deprecated

**Semantics.** SDBM delete failure flag. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### STREAM_INPUT_BODY

**Status:** Deprecated

**Semantics.** Writable raw request body. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### STREAM_OUTPUT_BODY

**Status:** Deprecated

**Semantics.** Writable raw response body. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### USERAGENT_IP

**Status:** Deprecated

**Semantics.** Client address from a proxy header. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.

### WEBSERVER_ERROR_LOG

**Status:** Deprecated

**Semantics.** Messages the host wrote to its error log. ModSecurity v2 only (ADR-0011).

**Implemented by.** v2.


## Engine-specific variables

Reserved names; not specified (ADR-0010).

### ARGS_PATH

**Status:** Engine-specific

**Semantics.** Coraza: arguments extracted from the path by restpath.

**Implemented by.** Coraza.

### ARGUMENTS_LIMIT_REACHED

**Status:** Engine-specific

**Semantics.** Coraza: 1 when SecArgumentsLimit truncated ARGS.

**Implemented by.** Coraza.

### JSON

**Status:** Engine-specific

**Semantics.** Coraza: parsed JSON body.

**Implemented by.** Coraza.

### MSC_PCRE_ERROR

**Status:** Engine-specific

**Semantics.** v3: 1 on a PCRE error.

**Implemented by.** v3.

### MSC_PCRE_LIMITS_EXCEEDED

**Status:** Engine-specific

**Semantics.** v3: 1 when PCRE limits were hit.

**Implemented by.** v3.

### MULTIPART_DUPLICATE_PART_HEADER

**Status:** Engine-specific

**Semantics.** libmodsecurity v3.0.17 and Coraza: multipart anomaly flag.

**Implemented by.** v3, Coraza.

### MULTIPART_FILENAME_CHARSET

**Status:** Engine-specific

**Semantics.** libmodsecurity v3.0.17 and Coraza: RFC 5987 filename* charset.

**Implemented by.** v3, Coraza.

### MULTIPART_FILENAME_LANGUAGE

**Status:** Engine-specific

**Semantics.** libmodsecurity v3.0.17 and Coraza: RFC 5987 filename* language.

**Implemented by.** v3, Coraza.

### REQUEST_XML

**Status:** Engine-specific

**Semantics.** Coraza: alias of XML.

**Implemented by.** Coraza.

### RES_BODY_ERROR

**Status:** Engine-specific

**Semantics.** Coraza: response body processor error flag.

**Implemented by.** Coraza.

### RES_BODY_ERROR_MSG

**Status:** Engine-specific

**Semantics.** Coraza: response body processor error message.

**Implemented by.** Coraza.

### RES_BODY_PROCESSOR

**Status:** Engine-specific

**Semantics.** Coraza: response body processor.

**Implemented by.** Coraza.

### RES_BODY_PROCESSOR_ERROR

**Status:** Engine-specific

**Semantics.** Coraza: response body processor error.

**Implemented by.** Coraza.

### RES_BODY_PROCESSOR_ERROR_MSG

**Status:** Engine-specific

**Semantics.** Coraza: response body processor error message.

**Implemented by.** Coraza.

### RESPONSE_ARGS

**Status:** Engine-specific

**Semantics.** Coraza: arguments parsed from the response.

**Implemented by.** Coraza.

### RESPONSE_XML

**Status:** Engine-specific

**Semantics.** Coraza: parsed XML response.

**Implemented by.** Coraza.

### STATUS

**Status:** Engine-specific

**Semantics.** v3: response status.

**Implemented by.** v3.

### URI_PARSE_ERROR

**Status:** Engine-specific

**Semantics.** Coraza: 1 when the URI failed to parse.

**Implemented by.** Coraza.

