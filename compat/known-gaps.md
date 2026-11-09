# Known conformance gaps

Core tests in `tests/` that a surveyed engine is known to fail today, with the spec
section that decides the behaviour. The engines are ModSecurity v2 (`v2/master`,
2026-09), libmodsecurity v3.0.17 and Coraza v3.8.1, as read from source on 2026-10-06
and 2026-10-07 (libmodsecurity rechecked against v3.0.17 on 2026-11-09, ModSecurity v2
run as v2.9.15 from 2026-11-09). Every row is **verified**: `adapters/coraza`,
`adapters/libmodsecurity` and `adapters/modsecurity2` run every test in CI and fail when a
listed file passes or an unlisted one fails. An entry here is a bug for the engine, not a
weakness of the test. Entries are removed when the engine is fixed; new ones are added
whenever a Divergence ADR or a divergence note picks against an engine.

| Test | Engine | Behaviour today | Decided in |
|---|---|---|---|
| `tests/engine/body/files-combined-size-fields.yaml` | Coraza | `FILES_COMBINED_SIZE` includes the bytes of non-file fields (`internal/bodyprocessors/multipart.go`, `totalSize` grows in the field branch too) | `05-variables.md#files_combined_size` |
| `tests/engine/directives/secrequestbodyjsondepthlimit.yaml` | ModSecurity v2 | top-level object not counted toward `SecRequestBodyJsonDepthLimit`; limit 2 accepts depth 3 | `04-directives.md#secrequestbodyjsondepthlimit` |
| `tests/engine/directives/secrequestbodylimit-boundary.yaml` | Coraza | a body of exactly `SecRequestBodyLimit` bytes is rejected (`transaction.go`, `>= tx.RequestBodyLimit`; v2 and v3 use `>`) | `04-directives.md#secrequestbodylimit` |
| `tests/engine/directives/secresponsebodylimit-boundary.yaml` | Coraza | a response of exactly `SecResponseBodyLimit` bytes is rejected (`transaction.go`, `WriteResponseBody`, `>=`; v2 and v3 use `>`) | `04-directives.md#secresponsebodylimit` |
| `tests/engine/directives/secresponsebodylimit-uninspected.yaml` | Coraza | `SecResponseBodyLimit` enforced on a response whose type is not inspected (`transaction.go`, `WriteResponseBody` checks the limit before `IsResponseBodyProcessable`) | `04-directives.md#secresponsebodylimit` |
| `tests/engine/lexical/case-insensitive-names.yaml` | Coraza | operator names matched case-sensitively | ADR-0002 |
| `tests/engine/lexical/comment-with-trailing-backslash.yaml` | Coraza | continued comment parsed as a directive | ADR-0013 |
| `tests/engine/grammar/directive-line-whitespace.yaml` | Coraza | tab between arguments is a load error | `02-grammar.md#directive-line` |
| `tests/engine/grammar/secrule-requires-id.yaml` | Coraza | rule without `id` loads (default build) | ADR-0015 |
| `tests/engine/processing/default-phase.yaml` | libmodsecurity v3 | phase-less rule runs in phase 1 | ADR-0017 |
| `tests/engine/processing/default-action-no-phase.yaml` | libmodsecurity v3 | missing phase defaults to 1 | ADR-0014 |
| `tests/engine/processing/default-action-redefined.yaml` | ModSecurity v2 | second `SecDefaultAction` replaces the first | ADR-0014 |
| `tests/engine/processing/phase4-without-inspection.yaml` | libmodsecurity v3 | phase 4 rules are not evaluated when the response body is not inspected (`src/transaction.cc`, `processResponseBody` returns before `evaluate(ResponseBodyPhase)` when `SecResponseBodyAccess` is not On or the type is not listed) | `03-processing-model.md#phases` |
| `tests/engine/processing/rule-exceptions-tag-literal.yaml` | ModSecurity v2 | `ByTag` parameter matched as an unanchored regular expression: `app/foo` also removes the rule tagged `app/foobar` (`apache2/re.c`, `msre_ruleset_rule_matches_exception`) | ADR-0029 |
| `tests/engine/processing/skipafter-missing-marker.yaml` | libmodsecurity v3, Coraza | `skipAfter` naming a marker that does not exist disables every later phase | ADR-0016 |
| `tests/engine/processing/rule-exceptions-bad-range.yaml` | ModSecurity v2 | `200-100` accepted silently | `03-processing-model.md#rule-exceptions` |
| `tests/engine/processing/rule-exceptions-unknown-id.yaml` | Coraza | `SecRuleUpdateTargetById` with an unknown id is an error | `03-processing-model.md#rule-exceptions` |
| `tests/engine/actions/setvar.yaml` | Coraza | any `setvar` without `=value` (`setvar:tx.x`, `setvar:!tx.x`) dereferences a nil macro and panics (`internal/actions/setvar.go` `Evaluate`) | `08-actions.md#setvar` |
| `tests/engine/lexical/quoted-arguments.yaml` | libmodsecurity v3 | `\"` inside an operator argument keeps its backslash (`seclang-scanner.ll`) | `01-lexical.md#quoting-and-escapes` |
| `tests/engine/directives/secargumentseparator.yaml` | Coraza | directive parsed and ignored | `04-directives.md#secargumentseparator`, ADR-0005 |
| `tests/engine/directives/deprecated-directive-accepted.yaml` | none | `SecHashEngine Off` is accepted everywhere; see ADR-0005 for the Deprecated names v3 and Coraza reject | ADR-0005 |
| `tests/engine/processing/skipafter-rule-id.yaml` | ModSecurity v2 | `skipAfter:4091` resumes after rule 4091 through a `RULE_PH_SKIPAFTER` placeholder (`apache2/apache2_config.c`) | ADR-0028 |
| `tests/engine/variables/scalar-unset.yaml` | ModSecurity v2 | an unset scalar yields no value at all (`apache2/re_variables.c`, the generators `return 0` when the datum is `NULL`), so a negated operator does not match and `&` counts 0 | `05-variables.md#collection-keys` |
| `tests/engine/variables/body-errors.yaml` | ModSecurity v2 | a JSON body that fails to parse aborts the transaction with status 500 before phase 2, so no rule sees `REQBODY_ERROR` (`apache2/msc_reqbody.c` `modsecurity_request_body_end` returns -1 after `json_complete` fails; `apache2/apache2_io.c` `read_request_body` turns that into `HTTP_INTERNAL_SERVER_ERROR`) | `05-variables.md#reqbody_error` |
| `tests/unit/operators/containsWord.json` | ModSecurity v2 | digits and `_` are word bytes, so `def` is not a word in `abc\0def ghi` (`apache2/re_operators.c` `msre_op_containsWord_execute`) (one case) | `06-operators.md#containsword` |
| `tests/unit/operators/ipMatch.json` | Coraza | `::ffff:ffff:ffff` does not match `0:0::/80` (one case) | `06-operators.md#ipmatch` |
| `tests/unit/transformations/uppercase-extra.json` | ModSecurity v2 | `t:uppercase` not implemented | ADR-0012 |
| `tests/unit/transformations/cssDecode.json` | Coraza | escapes of three or more hex digits decode to the UTF-8 encoding of the code point instead of its low byte, and code points above U+FFFF become U+FFFD (two cases) | `07-transformations.md#cssdecode` |
| `tests/unit/transformations/urlDecodeUni.json` | Coraza | one full-width `%u` case decodes differently | `07-transformations.md#urldecodeuni` |
| `tests/engine/actions/allow.yaml` | Coraza | `allow` also skips the logging phase | `08-actions.md#allow` |
| `tests/unit/transformations/htmlEntityDecode.json` | Coraza | `&nbsp;` decodes to UTF-8 `C2 A0` (two cases) | `07-transformations.md#htmlentitydecode` |
| `tests/unit/transformations/htmlEntityDecode-extra.json` | Coraza | `&shy;` decodes to UTF-8 `C2 AD` (`internal/transformations/html_entity_decode.go`, `html.UnescapeString`) (one case) | ADR-0031 |
| `tests/engine/variables/multipart.yaml` | Coraza | `FILES` members keyed by the empty string, so `FILES:field` selects nothing | `05-variables.md#files` |
| `tests/unit/operators/beginsWith.json`, `tests/unit/operators/contains.json`, `tests/unit/operators/endsWith.json`, `tests/unit/operators/streq.json`, `tests/unit/operators/within.json` | libmodsecurity v3, Coraza | an empty operator parameter is a load error (Coraza: "empty data"; v3: a parser syntax error, the parameter cannot be written at all); the spec says an empty string matches every value (one case per file) | `06-operators.md#contains` |
| `tests/unit/transformations/hexDecode.json` | Coraza | an input with an odd length is returned unchanged instead of decoding the complete pairs (one case) | `07-transformations.md#hexdecode` |
| `tests/unit/transformations/compressWhitespace-extra.json` | libmodsecurity v3 | byte 0xA0 is not whitespace (`isspace` only, `src/actions/transformations/compress_whitespace.cc`); v2 and Coraza compress it | ADR-0026 |
| `tests/unit/transformations/normalisePathWin-extra.json` | libmodsecurity v3, ModSecurity v2 | a backslash reached while skipping a run of slashes is kept instead of converted (v3 `normalise_path.cc`, only the current and next byte are converted; v2 `apache2/msc_util.c` `normalize_path_inplace` is the same) | `07-transformations.md#normalisepathwin` |
| `tests/unit/transformations/utf8toUnicode-extra.json` | libmodsecurity v3, Coraza | a malformed lead byte is not left unchanged: v3 drops it (`utf8_to_unicode.cc`), Coraza emits `%ufffd` (`utf8_to_unicode.go`, Go `range` decoding) (one case) | `07-transformations.md#utf8tounicode` |
| `tests/engine/grammar/chain-member-without-actions.yaml` | libmodsecurity v3 | a chain member without an action list is a parse error unless it is the last directive of the file ("Expecting an action", `seclang-scanner.ll`); other profiles give their chain members `"t:none"` so their own subject stays testable | `02-grammar.md#secrule-structure` |
| `tests/engine/body/json-args.yaml` | libmodsecurity v3, ModSecurity v2 | JSON leaves are added to `ARGS` only, never to `ARGS_POST` (v3: `request_body_processor/json.cc` calls `addArgument("JSON", …)`, which `transaction.cc` routes to `ARGS_GET`/`ARGS_POST` only for `GET`/`POST`; v2: `apache2/msc_json.c` gives them origin `JSON` and `apache2/re_variables.c` `var_args_post_generate` keeps origin `BODY` only) | `09-body-processors.md#json` |
| `tests/engine/directives/secresponsebodymimetype.yaml`, `tests/engine/directives/secresponsebodymimetypesclear.yaml` | libmodsecurity v3 | `SecResponseBodyMimeTypesClear` discards every `SecResponseBodyMimeType` of the same configuration, including those written after it (`rules_set_properties.h` clears the whole set at merge time when `m_clear` is set) | `04-directives.md#secresponsebodymimetypesclear` |
| `tests/engine/processing/default-action.yaml` | libmodsecurity v3 | the disruptive action of `SecDefaultAction` is applied only to rules carrying `block`; a matching rule with no disruptive action of its own passes (`rule_with_actions.cc`, "Ignoring action … (rule does not cotains block)") | `04-directives.md#secdefaultaction` |
| `tests/engine/variables/persistent-collections.yaml` | libmodsecurity v3 | `setvar` runs before `initcol` within one rule (`rule_with_actions.cc` `executeActionsIndependentOfChainedRuleResult` evaluates the setvars first), so a member written by the initialising rule is lost when the collection did not exist yet | `05-variables.md#persistent-collections` |
| `tests/unit/operators/rx.json` | libmodsecurity v3 | an empty `@rx` parameter is a parser syntax error (one case) | `06-operators.md#rx` |
| `tests/unit/operators/containsWord.json` | libmodsecurity v3 | an empty parameter is a parser syntax error (one case) | `06-operators.md#containsword` |
| `tests/engine/operators/ipmatch-invalid-entry.yaml` | Coraza | an unparsable `@ipMatch` entry is skipped instead of rejecting the configuration (`internal/operators/ip_match.go`) | ADR-0024 |

## Divergences no test can observe

Recorded here so they are not lost; they are not rows above because the adapters would
otherwise report them as obsolete.

- Coraza marks a transaction audit-relevant only when a rule carried `auditlog`
  explicitly, and when `SecAuditLogRelevantStatus` is set it also requires the status to
  match (`10-logging.md#audit-log-relevance`).
- Coraza built with `coraza.rule.case_sensitive_args_keys` compares `ARGS` keys exactly
  (ADR-0008); the default build conforms.
- Coraza calls its error-log callback only for rules carrying `log` explicitly; ModSecurity
  logs by default (`08-actions.md#log`).
- libmodsecurity v3 parses `ctl:forceRequestBodyVariable` without implementing it, but it
  fills `REQUEST_BODY` for every buffered body, so `tests/engine/body/no-processor.yaml`
  and `tests/engine/actions/ctl-options.yaml` pass anyway (ADR-0022).

Not listed: differences the specification leaves unspecified (defaults, status codes,
empty `Include` globs), since no test asserts on them.
