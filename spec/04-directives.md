# 04. Directives

One section per directive. Sections are grouped by purpose; the index below lists every
directive name known to any surveyed engine, with its status (`00-conventions.md`) and
which engines accept the name at all (`compat/matrix.md`). Accepting a name is not
implementing it: Coraza, for example, parses and ignores several directives, which is
why `04-directives.md` and ADR-0005 distinguish the two.

Defaults are listed per engine. A default is normative only when the three engines
agree; otherwise it is left unspecified and portable configurations set the directive
explicitly, as both engines' recommended configuration files do.

## Index

| Directive | Status | v2 | v3 | Coraza | Purpose |
|---|---|---|---|---|---|
| [Include](#include) | Core | yes | yes | yes | Parse another configuration file in place |
| [SecAction](#secaction) | Core | yes | yes | yes | Unconditional rule |
| [SecArgumentSeparator](#secargumentseparator) | Core | yes | yes | yes | Character separating urlencoded arguments |
| [SecArgumentsLimit](#secargumentslimit) | Core | yes | yes | yes | Maximum number of arguments parsed |
| [SecAuditEngine](#secauditengine) | Core | yes | yes | yes | Audit logging mode |
| [SecAuditLog](#secauditlog) | Core | yes | yes | yes | Audit log destination |
| [SecAuditLog2](#secauditlog2) | Deprecated | yes | yes | - | Secondary audit log destination |
| [SecAuditLogDirMode](#secauditlogdirmode) | Extended | yes | yes | yes | Permissions of created audit directories |
| [SecAuditLogFileMode](#secauditlogfilemode) | Extended | yes | yes | yes | Permissions of created audit files |
| [SecAuditLogFormat](#secauditlogformat) | Core | yes | yes | yes | Audit log serialization format |
| [SecAuditLogParts](#secauditlogparts) | Core | yes | yes | yes | Which parts an audit entry contains |
| [SecAuditLogPrefix](#secauditlogprefix) | Engine-specific | - | yes | - | Prefix for concurrent audit file names |
| [SecAuditLogRelevantStatus](#secauditlogrelevantstatus) | Core | yes | yes | yes | Status regex selecting relevant transactions |
| [SecAuditLogStorageDir](#secauditlogstoragedir) | Core | yes | yes | yes | Directory for concurrent audit files |
| [SecAuditLogType](#secauditlogtype) | Core | yes | yes | yes | Serial or concurrent audit logging |
| [SecCacheTransformations](#seccachetransformations) | Deprecated | yes | yes | - | Cache transformation results |
| [SecChrootDir](#secchrootdir) | Deprecated | yes | yes | - | Chroot the server process |
| [SecCollectionTimeout](#seccollectiontimeout) | Extended | yes | yes | yes | Expiry of persistent collections |
| [SecComponentSignature](#seccomponentsignature) | Core | yes | yes | yes | Append a component to the engine signature |
| [SecConnEngine](#secconnengine) | Deprecated | yes | yes | yes | Connection limiting engine |
| [SecConnReadStateLimit](#secconnreadstatelimit) | Deprecated | yes | yes | yes | Max connections in read state per IP |
| [SecConnWriteStateLimit](#secconnwritestatelimit) | Deprecated | yes | yes | yes | Max connections in write state per IP |
| [SecContentInjection](#seccontentinjection) | Deprecated | yes | yes | - | Enable append/prepend |
| [SecCookieFormat](#seccookieformat) | Extended | yes | yes | yes | Cookie parsing version |
| [SecCookieV0Separator](#seccookiev0separator) | Extended | yes | yes | - | Separator for version 0 cookies |
| [SecDataDir](#secdatadir) | Core | yes | yes | yes | Directory for persistent storage |
| [SecDataset](#secdataset) | Engine-specific | - | - | yes | Inline dataset for @pmFromDataset/@ipMatchFromDataset |
| [SecDebugLog](#secdebuglog) | Core | yes | yes | yes | Debug log destination |
| [SecDebugLogLevel](#secdebugloglevel) | Core | yes | yes | yes | Debug log verbosity |
| [SecDefaultAction](#secdefaultaction) | Core | yes | yes | yes | Default action list per phase |
| [SecDisableBackendCompression](#secdisablebackendcompression) | Deprecated | yes | yes | - | Strip Accept-Encoding toward the backend |
| [SecGeoLookupDb](#secgeolookupdb) | Extended | yes | yes | - | GeoIP database path |
| [SecGsbLookupDb](#secgsblookupdb) | Deprecated | yes | yes | yes | Google Safe Browsing database |
| [SecGuardianLog](#secguardianlog) | Deprecated | yes | yes | - | Pipe to the httpd-guardian script |
| [SecHashEngine](#sechashengine) | Deprecated | yes | yes | yes | Hash engine (link integrity) |
| [SecHashKey](#sechashkey) | Deprecated | yes | yes | yes | Hash engine key |
| [SecHashMethodPm](#sechashmethodpm) | Deprecated | yes | yes | yes | Hash engine phrase matching |
| [SecHashMethodRx](#sechashmethodrx) | Deprecated | yes | yes | yes | Hash engine regex matching |
| [SecHashParam](#sechashparam) | Deprecated | yes | yes | yes | Hash engine parameter name |
| [SecHttpBlKey](#sechttpblkey) | Extended | yes | yes | yes | Project Honey Pot key for @rbl |
| [SecIgnoreRuleCompilationErrors](#secignorerulecompilationerrors) | Engine-specific | - | - | yes | Continue loading after a rule error |
| [SecInterceptOnError](#secinterceptonerror) | Deprecated | yes | yes | - | Intercept on processing errors |
| [SecMarker](#secmarker) | Core | yes | yes | yes | Named target for skipAfter |
| [SecParseXmlIntoArgs](#secparsexmlintoargs) | Extended | yes | yes | - | Expose XML content as ARGS |
| [SecPcreMatchLimit](#secpcrematchlimit) | Extended | yes | yes | yes | PCRE match limit |
| [SecPcreMatchLimitRecursion](#secpcrematchlimitrecursion) | Extended | yes | yes | yes | PCRE recursion limit |
| [SecReadStateLimit](#secreadstatelimit) | Deprecated | yes | - | - | Older name of SecConnReadStateLimit |
| [SecRemoteRules](#secremoterules) | Extended | yes | yes | yes | Load rules from a URL |
| [SecRemoteRulesFailAction](#secremoterulesfailaction) | Extended | yes | yes | yes | Behaviour when remote rules fail to load |
| [SecRequestBodyAccess](#secrequestbodyaccess) | Core | yes | yes | yes | Buffer and inspect request bodies |
| [SecRequestBodyInMemoryLimit](#secrequestbodyinmemorylimit) | Extended | yes | - | yes | Memory buffer size before spooling to disk |
| [SecRequestBodyJsonDepthLimit](#secrequestbodyjsondepthlimit) | Core | yes | yes | yes | Maximum JSON nesting depth |
| [SecRequestBodyLimit](#secrequestbodylimit) | Core | yes | yes | yes | Maximum request body size |
| [SecRequestBodyLimitAction](#secrequestbodylimitaction) | Core | yes | yes | yes | What to do above the limit |
| [SecRequestBodyNoFilesLimit](#secrequestbodynofileslimit) | Core | yes | yes | yes | Maximum request body size excluding files |
| [SecRequestEncoding](#secrequestencoding) | Deprecated | yes | - | - | Declared request character encoding |
| [SecResponseBodyAccess](#secresponsebodyaccess) | Core | yes | yes | yes | Buffer and inspect response bodies |
| [SecResponseBodyJsonDepthLimit](#secresponsebodyjsondepthlimit) | Engine-specific | - | - | yes | Maximum response JSON nesting depth |
| [SecResponseBodyLimit](#secresponsebodylimit) | Core | yes | yes | yes | Maximum response body size |
| [SecResponseBodyLimitAction](#secresponsebodylimitaction) | Core | yes | yes | yes | What to do above the limit |
| [SecResponseBodyMimeType](#secresponsebodymimetype) | Core | yes | yes | yes | Response types to inspect |
| [SecResponseBodyMimeTypesClear](#secresponsebodymimetypesclear) | Core | yes | yes | yes | Reset the inspected type list |
| [SecRule](#secrule) | Core | yes | yes | yes | Conditional rule |
| [SecRuleEngine](#secruleengine) | Core | yes | yes | yes | Rule processing mode |
| [SecRuleInheritance](#secruleinheritance) | Extended | yes | yes | - | Inherit rules into child contexts |
| [SecRulePerfTime](#secruleperftime) | Extended | yes | yes | yes | Log slow rules |
| [SecRuleRemoveById](#secruleremovebyid) | Core | yes | yes | yes | Remove rules by id |
| [SecRuleRemoveByMsg](#secruleremovebymsg) | Extended | yes | yes | yes | Remove rules by message |
| [SecRuleRemoveByTag](#secruleremovebytag) | Core | yes | yes | yes | Remove rules by tag |
| [SecRuleScript](#secrulescript) | Extended | yes | yes | yes | Lua rule |
| [SecRuleUpdateActionById](#secruleupdateactionbyid) | Core | yes | yes | yes | Edit actions of a rule |
| [SecRuleUpdateTargetById](#secruleupdatetargetbyid) | Core | yes | yes | yes | Edit variables of a rule by id |
| [SecRuleUpdateTargetByMsg](#secruleupdatetargetbymsg) | Extended | yes | yes | yes | Edit variables of rules by message |
| [SecRuleUpdateTargetByTag](#secruleupdatetargetbytag) | Core | yes | yes | yes | Edit variables of rules by tag |
| [SecRxPreFilter](#secrxprefilter) | Engine-specific | - | - | yes | Literal prefilter for @rx |
| [SecSensorId](#secsensorid) | Extended | yes | yes | yes | Sensor identifier in audit logs |
| [SecServerSignature](#secserversignature) | Extended | yes | yes | yes | Replace the server signature |
| [SecStatusEngine](#secstatusengine) | Deprecated | yes | yes | - | Report engine status upstream |
| [SecStreamInBodyInspection](#secstreaminbodyinspection) | Deprecated | yes | yes | - | Expose STREAM_INPUT_BODY |
| [SecStreamOutBodyInspection](#secstreamoutbodyinspection) | Deprecated | yes | yes | - | Expose STREAM_OUTPUT_BODY |
| [SecTmpDir](#sectmpdir) | Extended | yes | yes | yes | Directory for temporary files |
| [SecTmpSaveUploadedFiles](#sectmpsaveuploadedfiles) | Extended | yes | yes | - | Keep temporary upload files |
| [SecUnicodeCodePage](#secunicodecodepage) | Deprecated | yes | - | - | Code page for Unicode mapping |
| [SecUnicodeMapFile](#secunicodemapfile) | Extended | yes | yes | - | Unicode mapping file |
| [SecUploadDir](#secuploaddir) | Core | yes | yes | yes | Directory for kept uploads |
| [SecUploadFileLimit](#secuploadfilelimit) | Extended | yes | yes | yes | Maximum files per request |
| [SecUploadFileMode](#secuploadfilemode) | Core | yes | yes | yes | Permissions of kept uploads |
| [SecUploadKeepFiles](#secuploadkeepfiles) | Core | yes | yes | yes | Keep uploaded files |
| [SecWebAppId](#secwebappid) | Extended | yes | yes | yes | Application identifier for persistence and logs |
| [SecWriteStateLimit](#secwritestatelimit) | Deprecated | yes | - | - | Older name of SecConnWriteStateLimit |
| [SecXmlExternalEntity](#secxmlexternalentity) | Extended | yes | yes | - | Allow XML external entities |

## Rule-building directives

### Include

**Status:** Core

**Syntax.** `Include PATH`

**Semantics.** Defined in `01-lexical.md#include`: the named file, or every file matched
by a `*` glob, is parsed in place. Nested includes are permitted.

**Divergence notes.** Relative-path resolution differs (`01-lexical.md#include`).

**Tests.** `tests/engine/directives/include.yaml`,
`tests/engine/lexical/include-relative-file.yaml`

### SecAction

**Status:** Core

**Syntax.** `SecAction "ACTIONS"`

**Semantics.** An unconditional rule: it matches every transaction in its phase and runs
its action list (`02-grammar.md#secrule-structure`). `SecAction` is the idiomatic way to
initialise `TX` variables and to emit `ctl:` changes. It participates in `SecDefaultAction`
inheritance, chains, `skip`/`skipAfter` and rule exceptions exactly like a `SecRule`
whose operator always matches. It MUST carry an `id` unless it is a chain member.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/secaction.yaml`

### SecComponentSignature

**Status:** Core

**Syntax.** `SecComponentSignature "NAME/VERSION (COMMENT)"`

**Semantics.** Appends the string to the engine's component signature, which engines
include in audit log headers and debug logs so that the rule set version in use can be
identified. May appear more than once; each occurrence appends. No effect on rule
evaluation.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/seccomponentsignature.yaml`

### SecDefaultAction

**Status:** Core

**Syntax.** `SecDefaultAction "ACTIONS"`

**Semantics.** Defined in `03-processing-model.md#default-actions`. Constraints on the
action list are normative (ADR-0014).

**Default.** None in ModSecurity v2 and libmodsecurity v3: a rule that matches with no
disruptive action from any source passes. Coraza applies a built-in
`phase:2,log,auditlog,pass` (`internal/seclang/directives.go`). Observationally these
agree, since `pass` is the no-op disruptive action.

**Divergence notes.** See `03-processing-model.md#default-actions`.

**Tests.** `tests/engine/processing/default-action.yaml`,
`tests/engine/processing/default-action-no-phase.yaml`,
`tests/engine/processing/default-action-no-disruptive.yaml`

### SecMarker

**Status:** Core

**Syntax.** `SecMarker LABEL`

**Semantics.** Defines a phase-less label that `skipAfter:LABEL` jumps to
(`03-processing-model.md#flow-control`). A marker never evaluates anything, has no
actions and no id, and MAY be quoted. The same label MAY be defined more than once; the
first one after the skipping rule wins.

**Divergence notes.** None known.

**Tests.** `tests/engine/processing/skip-and-skipafter.yaml`

### SecRule

**Status:** Core

**Syntax.** `SecRule VARIABLES OPERATOR [ACTIONS]`

**Semantics.** The conditional rule, defined in `02-grammar.md#secrule-structure`,
`#variable-list`, `#operator` and `#action-list`, and evaluated as described in
`03-processing-model.md`. The variables are listed in `05-variables.md`, the operators in
`06-operators.md`, the transformations in `07-transformations.md` and the actions in
`08-actions.md`.

**Divergence notes.** None for the directive itself; see the referenced sections.

**Tests.** `tests/engine/grammar/variable-list.yaml` and every other engine-tier
profile in this repository.

### SecRuleRemoveById

**Status:** Core

**Syntax.** `SecRuleRemoveById ID|RANGE [ID|RANGE ...]`

**Semantics.** Removes every previously defined rule whose id is listed or falls in a
listed inclusive range (`03-processing-model.md#rule-exceptions`). Ids that match no rule
are ignored. A range with start greater than end MUST be a configuration error.

**Divergence notes.** ModSecurity v2 does not validate range order.

**Tests.** `tests/engine/directives/secruleremovebyid-range.yaml`,
`tests/engine/processing/rule-exceptions.yaml`,
`tests/engine/processing/rule-exceptions-bad-range.yaml`

### SecRuleRemoveByMsg

**Status:** Extended

**Syntax.** `SecRuleRemoveByMsg MSG`

**Semantics.** Removes every previously defined rule whose `msg` matches the regular
expression (`03-processing-model.md#rule-exceptions`). Implemented by ModSecurity v2,
libmodsecurity v3 and Coraza; Extended rather than Core because OWASP CRS does not use
it and `msg` values are not stable identifiers.

### SecRuleRemoveByTag

**Status:** Core

**Syntax.** `SecRuleRemoveByTag TAG`

**Semantics.** Removes every previously defined rule any of whose `tag` values equals
`TAG` (`03-processing-model.md#rule-exceptions`, ADR-0029).

**Divergence notes.** ModSecurity v2 matches `TAG` as an unanchored regular expression
(`apache2/re.c`, `msre_ruleset_rule_matches_exception`); libmodsecurity v3
(`src/rules_set.cc`, `containsTag`) and Coraza (`internal/corazawaf/rulegroup.go`,
`DeleteByTag`) compare exactly. See ADR-0029.

**Tests.** `tests/engine/processing/rule-exceptions.yaml`,
`tests/engine/processing/rule-exceptions-tag-literal.yaml`

### SecRuleUpdateActionById

**Status:** Core

**Syntax.** `SecRuleUpdateActionById ID|RANGE "ACTIONS"`

**Semantics.** Merges `ACTIONS` into each matching rule's action list; a disruptive
action replaces the existing one, cumulative actions are appended
(`03-processing-model.md#rule-exceptions`). `id` and `chain` MUST NOT appear in
`ACTIONS`.

**Divergence notes.** None known.

**Tests.** `tests/engine/processing/rule-exceptions-update-action.yaml`

### SecRuleUpdateTargetById

**Status:** Core

**Syntax.** `SecRuleUpdateTargetById ID|RANGE "TARGETS"`

**Semantics.** Appends `TARGETS` to the variable list of each matching rule; a target
beginning with `!` is an exclusion (`03-processing-model.md#rule-exceptions`). This is
the mechanism OWASP CRS documents for application-specific exclusions, used 57 times in
CRS v4 itself.

**Divergence notes.** None known.

**Tests.** `tests/engine/processing/rule-exceptions.yaml`

### SecRuleUpdateTargetByMsg

**Status:** Extended

**Syntax.** `SecRuleUpdateTargetByMsg MSG "TARGETS"`

**Semantics.** As `SecRuleUpdateTargetById`, selecting rules by `msg`. Implemented by
ModSecurity v2 and libmodsecurity v3; Coraza 3.8.1 accepts and ignores it (ADR-0005).

### SecRuleUpdateTargetByTag

**Status:** Core

**Syntax.** `SecRuleUpdateTargetByTag TAG "TARGETS"`

**Semantics.** As `SecRuleUpdateTargetById`, selecting every rule any of whose tags
equals `TAG` (ADR-0029).

**Divergence notes.** ModSecurity v2 matches `TAG` as an unanchored regular expression
(`apache2/apache2_config.c`, `msc_pregcomp`); libmodsecurity v3 (`src/rule_with_operator.cc`,
`containsTag`) and Coraza (`internal/seclang/directives.go`, `utils.InSlice`; added in
Coraza ADR-0012) compare exactly. See ADR-0029.

**Tests.** `tests/engine/directives/secruleupdatetargetbytag.yaml`

## Engine and body directives

### SecArgumentSeparator

**Status:** Core

**Syntax.** `SecArgumentSeparator CHAR`

**Default.** `&` (all engines).

**Scope.** Main configuration; applies to every transaction.

**Semantics.** The single character that separates `name=value` pairs when parsing the
query string and `application/x-www-form-urlencoded` request bodies into `ARGS_GET` and
`ARGS_POST`. Changing it to `;` supports applications that use the W3C-recommended
alternative separator.

**Divergence notes.** ModSecurity v2 (`apache2/msc_parsers.c`) and libmodsecurity v3
(`src/transaction.cc`, `m_secArgumentSeparator`) implement it for both the query string
and the body. Coraza 3.8.1 parses the directive and ignores it
(`directivesmap.gen.go` maps it to `directiveUnsupported`), so the test fails there: a
Core gap (ADR-0005).

**Tests.** `tests/engine/directives/secargumentseparator.yaml`

### SecArgumentsLimit

**Status:** Core

**Syntax.** `SecArgumentsLimit N`

**Default.** 1000 in ModSecurity v2 (`ARGUMENTS_LIMIT`) and Coraza (`waf.go`);
libmodsecurity v3 applies no limit until the directive is set. Unspecified.

**Semantics.** At most `N` arguments are added to `ARGS_GET` and `ARGS_POST` combined;
arguments parsed after the limit is reached are discarded and do not appear in any
collection or count. Engines SHOULD log the discard at debug level. Coraza additionally
exposes `ARGUMENTS_LIMIT_REACHED` (Engine-specific, `05-variables.md`).

**Divergence notes.** None for the discard behaviour (v2 `msc_parsers.c` "Skipping
request argument, over limit"; v3 `transaction.cc` same message; Coraza `waf.go`).

**Tests.** `tests/engine/directives/secargumentslimit.yaml`

### SecRequestBodyAccess

**Status:** Core

**Syntax.** `SecRequestBodyAccess On|Off`

**Default.** `Off` in ModSecurity v2 and Coraza; unset in libmodsecurity v3, which
behaves as `Off`. Normative default: `Off`.

**Semantics.** When `On`, the engine buffers the request body up to
`SecRequestBodyLimit`, runs the body processor selected by `Content-Type` or
`ctl:requestBodyProcessor`, and populates `ARGS_POST`, `REQUEST_BODY`, `FILES*`, `XML`
and `JSON` before phase 2. When `Off`, the body is not read and those variables are
empty. `ctl:requestBodyAccess` overrides the value for one transaction when set in
phase 1.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/secrequestbodyaccess.yaml`,
`tests/engine/directives/secrequestbodyaccess-off.yaml`

### SecRequestBodyLimit

**Status:** Core

**Syntax.** `SecRequestBodyLimit BYTES`

**Default.** 134217728 (128 MiB) in ModSecurity v2 (`REQUEST_BODY_DEFAULT_LIMIT`) and
Coraza (`waf.go`); libmodsecurity v3 applies no limit until set. Unspecified; both
recommended configurations set 13107200.

**Semantics.** The maximum request body size the engine will buffer, including file
uploads. What happens above the limit is governed by `SecRequestBodyLimitAction`. The
value MUST be a positive integer. The value `0` is **not specified**: libmodsecurity v3
treats it as "no limit" (`transaction.cc` tests `m_value > 0`), Coraza rejects it at
load time (`waf.go` `Validate`, "request body limit should be bigger than 0") and so
does ModSecurity v2 (`apache2_config.c`, "Invalid value for SecRequestBodyLimit" for
`limit <= 0`). Portable configurations never use `0`.

**Divergence notes.** The HTTP status used by `Reject` is 413 in ModSecurity v2
(`msc_reqbody.c`, `HTTP_REQUEST_ENTITY_TOO_LARGE`) and Coraza (`transaction.go`,
`setAndReturnBodyLimitInterruption(tx, 413)`) but 403 in libmodsecurity v3
(`transaction.cc`, `m_it.status = 403`). The tests therefore assert only that the
transaction is denied. Coraza also caps the value at 1 GiB, and treats a body of exactly
`BYTES` as over the limit (`transaction.go`, `>= tx.RequestBodyLimit`) where ModSecurity v2
uses `>`, as does libmodsecurity v3 (`transaction.cc`, `m_requestBodyLimit.m_value < len + current_size`);
`secrequestbodylimit-boundary.yaml` pins the boundary and Coraza fails it (`compat/known-gaps.md`).

**Tests.** `tests/engine/directives/secrequestbodylimit-reject.yaml`,
`tests/engine/directives/secrequestbodylimit-boundary.yaml`,
`tests/engine/directives/body-limit-directives-load.yaml`

### SecRequestBodyLimitAction

**Status:** Core

**Syntax.** `SecRequestBodyLimitAction Reject|ProcessPartial`

**Default.** `Reject` in ModSecurity v2 (`REQUEST_BODY_LIMIT_ACTION_REJECT`) and Coraza;
unset in libmodsecurity v3. Unspecified.

**Semantics.** `Reject`: when the body exceeds `SecRequestBodyLimit` the transaction is
interrupted with a `deny` before phase 2 rules run; the interruption carries no rule id
(adapters report `rule_id: 0`). `ProcessPartial`: the first `SecRequestBodyLimit` bytes
are buffered and processed, the rest is discarded, `INBOUND_DATA_ERROR` is set to `1`,
and phase 2 rules run normally. In `DetectionOnly`, `Reject` MUST NOT interrupt; the engines
then process the whole body and still set `INBOUND_DATA_ERROR` to `1` (ModSecurity v2
`apache2/mod_security2.c`, the `inbound_error = 1` branch for `DetectionOnly`; Coraza v3.8.1
`internal/corazawaf/transaction.go`, which sets the flag before choosing the action).

**Divergence notes.** Status code for `Reject` differs (see `#secrequestbodylimit`).

**Tests.** `tests/engine/directives/secrequestbodylimit-processpartial.yaml`,
`tests/engine/directives/secrequestbodylimit-reject.yaml`

### SecRequestBodyNoFilesLimit

**Status:** Core

**Syntax.** `SecRequestBodyNoFilesLimit BYTES`

**Default.** 1048576 (1 MiB) in ModSecurity v2 (`REQUEST_BODY_NO_FILES_DEFAULT_LIMIT`)
and Coraza; unset in libmodsecurity v3. Unspecified.

**Semantics.** A second size limit that excludes the bytes of uploaded files in
`multipart/form-data` bodies, so that large uploads can be allowed while keeping the
inspected part of the body small. Exceeding it MUST be treated as exceeding
`SecRequestBodyLimit` under `SecRequestBodyLimitAction`.

**Divergence notes.** The enforcement path differs: ModSecurity v2 rejects
(`msc_reqbody.c`); libmodsecurity v3 sets `REQBODY_ERROR`, `REQBODY_ERROR_MSG` and
`INBOUND_DATA_ERROR` (`transaction.cc`); Coraza 3.8.1 reads the directive but
implements no logic (`waf.go`, "TODO ... no logic based on it is implemented", issue
896). Until a Divergence ADR fixes the observable behaviour, the test only checks that
the directive loads. A Core gap for Coraza (ADR-0005).

**Tests.** `tests/engine/directives/body-limit-directives-load.yaml`

### SecRequestBodyInMemoryLimit

**Status:** Extended

**Syntax.** `SecRequestBodyInMemoryLimit BYTES`

**Default.** 131072 in ModSecurity v2 (`REQUEST_BODY_DEFAULT_INMEMORY_LIMIT`); equal to
`SecRequestBodyLimit` in Coraza (`waf.go`). Unspecified.

**Semantics.** The number of request body bytes held in memory before the engine spools
the remainder to a temporary file (ModSecurity v2 `apache2/msc_reqbody.c`, Coraza
`internal/corazawaf/body_buffer.go`). It has no effect on rule evaluation; it exists so
that deployments can bound memory use. Extended rather than Core because libmodsecurity
v3 rejects it (ADR-0025); a profile that uses it declares `requires:`.

**Divergence notes.** libmodsecurity v3 rejects the directive with "is no longer
supported" (`seclang-parser.yy`), so the matrix lists it absent there and the profile
below is skipped by its adapter.

**Tests.** `tests/engine/directives/secrequestbodyinmemorylimit.yaml`

### SecRequestBodyJsonDepthLimit

**Status:** Core

**Syntax.** `SecRequestBodyJsonDepthLimit N`

**Default.** 10000 in ModSecurity v2 (`REQUEST_BODY_JSON_DEPTH_DEFAULT_LIMIT`) and
libmodsecurity v3 (`json.cc`, `json_depth_limit_default`); 1024 in Coraza (`waf.go`,
`DefaultRequestBodyJsonDepthLimit`). Unspecified.

**Semantics.** The maximum nesting depth of a JSON request body processed by the `JSON`
body processor. A body nested deeper MUST be treated as a body processing error:
`REQBODY_ERROR` is set to `1` and `REQBODY_ERROR_MSG` describes the failure; rules then
decide what to do, as OWASP CRS rule 200002 does. Depth counts every object or array
entered, the top-level one included: `{"a":{"b":1}}` has depth 2.

**Divergence notes.** ModSecurity v2 does not count a top-level object
(`apache2/msc_json.c`, `yajl_start_map` returns before `current_depth++` when there is no
current key), so with a limit of 2 it accepts `{"a":{"b":{"c":1}}}`; a top-level array is
counted. libmodsecurity v3 and Coraza count the root. See `compat/known-gaps.md`.

**Divergence notes.** Defaults differ as listed.

**Tests.** `tests/engine/directives/secrequestbodyjsondepthlimit.yaml`

### SecResponseBodyAccess

**Status:** Core

**Syntax.** `SecResponseBodyAccess On|Off`

**Default.** `Off` in ModSecurity v2 and Coraza; unset in libmodsecurity v3, which
behaves as `Off`. Normative default: `Off`.

**Semantics.** When `On`, and the response `Content-Type` is listed by
`SecResponseBodyMimeType`, the engine buffers the response body up to
`SecResponseBodyLimit` and makes it available as `RESPONSE_BODY` in phase 4. When `Off`,
phase 4 runs with an empty `RESPONSE_BODY`.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/secresponsebodyaccess.yaml`,
`tests/engine/directives/secresponsebodyaccess-off.yaml`

### SecResponseBodyLimit

**Status:** Core

**Syntax.** `SecResponseBodyLimit BYTES`

**Default.** 524288 (512 KiB) in ModSecurity v2 (`RESPONSE_BODY_DEFAULT_LIMIT`) and
Coraza (`waf.go`); libmodsecurity v3 applies no limit until set. Unspecified.

**Semantics.** The maximum response body size the engine will buffer. Behaviour above
the limit is governed by `SecResponseBodyLimitAction`. The limit applies only to a
response whose body is inspected (`SecResponseBodyAccess` On and a listed type); any
other response passes untouched whatever its size.

**Divergence notes.** Coraza treats a response of exactly `BYTES` as over the limit
(`transaction.go`, `>=`), ModSecurity v2 and libmodsecurity v3 use `>`; `secresponsebodylimit-boundary.yaml` pins the boundary and Coraza fails it (`compat/known-gaps.md`).
Coraza also enforces the limit on a response whose type is not inspected
(`transaction.go`, `WriteResponseBody` checks the limit before `IsResponseBodyProcessable`),
where ModSecurity v2 (`apache2/apache2_io.c`, `of_skipping`) and libmodsecurity v3
(`src/transaction.cc`, `appendResponseBody` returns before the limit) do not;
`secresponsebodylimit-uninspected.yaml` fails on Coraza (`compat/known-gaps.md`).

**Tests.** `tests/engine/directives/secresponsebodylimit-processpartial.yaml`,
`tests/engine/directives/secresponsebodylimit-uninspected.yaml`,
`tests/engine/directives/secresponsebodylimit-boundary.yaml`,
`tests/engine/directives/body-limit-directives-load.yaml`

### SecResponseBodyLimitAction

**Status:** Core

**Syntax.** `SecResponseBodyLimitAction Reject|ProcessPartial`

**Default.** `Reject` in ModSecurity v2 (`RESPONSE_BODY_LIMIT_ACTION_REJECT`);
`ProcessPartial` in Coraza (`waf.go`, `BodyLimitActionProcessPartial`); unset in
libmodsecurity v3. Unspecified, and this is the one body-limit default where engines
disagree on *behaviour* rather than on a number: configurations MUST set it.

**Semantics.** `Reject`: a response larger than the limit is replaced by a `deny`
interruption whose status code is **not specified**: ModSecurity v2 (`apache2/apache2_io.c`,
`HTTP_INTERNAL_SERVER_ERROR`) and Coraza (`transaction.go`,
`setAndReturnBodyLimitInterruption(tx, 500)`) send 500, libmodsecurity v3 sends 403
(`transaction.cc`). The test asserts the denial only. `ProcessPartial`: the first `SecResponseBodyLimit` bytes are inspected,
`OUTBOUND_DATA_ERROR` is set to `1`, and the full response is delivered.

**Divergence notes.** Defaults differ as listed.

**Tests.** `tests/engine/directives/secresponsebodylimit-reject.yaml`,
`tests/engine/directives/secresponsebodylimit-processpartial.yaml`

### SecResponseBodyMimeType

**Status:** Core

**Syntax.** `SecResponseBodyMimeType TYPE [TYPE ...]`

**Default.** ModSecurity v2 inspects `text/plain` and `text/html`
(`apache2_config.c`); libmodsecurity v3 inspects every type until the directive is set
(`transaction.cc`, the type check runs only when `m_set`); Coraza inspects none until set
(`transaction.go`, `IsResponseBodyProcessable`). Unspecified; both recommended
configurations set the list.

**Semantics.** Adds the given media types to the set whose response bodies are buffered
and inspected (`#secresponsebodyaccess`). Multiple occurrences accumulate. Types are
compared against the response `Content-Type` with any parameters (`; charset=…`)
removed; whether the comparison ignores case is **not specified** (ModSecurity v2
compares case-insensitively through `apr_table_get`, libmodsecurity v3.0.17 lower-cases
the response type before the lookup (`transaction.cc`, `processResponseBody`; v3.0.16
compared exactly), Coraza compares exactly). The tests use bare, lowercase `Content-Type` values so that neither
parameter stripping nor case is what they measure.

**Divergence notes.** Defaults differ as listed.

**Tests.** `tests/engine/directives/secresponsebodymimetype.yaml`

### SecResponseBodyMimeTypesClear

**Status:** Core

**Syntax.** `SecResponseBodyMimeTypesClear`

**Semantics.** Empties the set of inspected response media types, including any engine
default, so that a following `SecResponseBodyMimeType` defines it from scratch.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/secresponsebodymimetypesclear.yaml`

### SecResponseBodyJsonDepthLimit

**Status:** Engine-specific

**Syntax.** `SecResponseBodyJsonDepthLimit N`

**Semantics.** Coraza only (Coraza ADR-0059): the response-side counterpart of
`SecRequestBodyJsonDepthLimit` for the response JSON body processor, default 1024.
Neither ModSecurity branch parses response bodies as JSON.

### SecRuleEngine

**Status:** Core

**Syntax.** `SecRuleEngine On|Off|DetectionOnly`

**Default.** `Off` in ModSecurity v2 (`apache2_config.c`, `is_enabled = 0`). `On` in
Coraza (`internal/corazawaf/waf.go`, `RuleEngine: types.RuleEngineOn`). libmodsecurity
v3 leaves the value unset (`PropertyNotSetRuleEngine`), in which state rules are
evaluated and logged but never interrupt, equivalent to `DetectionOnly`. Because the
three defaults differ, rulesets MUST set it explicitly and this specification does not
standardize the default.

**Scope.** Main configuration and any included file. The last occurrence before a
transaction starts wins. `ctl:ruleEngine` changes the value for the current
transaction only.

**Semantics.**

- `On`: rules are evaluated and disruptive actions (`deny`, `drop`, `redirect`,
  `allow`) take effect.
- `DetectionOnly`: rules are evaluated, matches are logged, variables are set, but no
  disruptive action interrupts the transaction. The status code of the transaction is
  unaffected.
- `Off`: no rules are evaluated. Nothing is logged by rules. Request and response body
  handling directives still apply where the engine needs them for other purposes.

**Divergence notes.** None known for the three values. The defaults differ as listed
above; every published ruleset sets the directive, so the default is left unspecified.

**Tests.** `tests/engine/directives/secruleengine-on.yaml`,
`tests/engine/directives/secruleengine-detectiononly.yaml`,
`tests/engine/directives/secruleengine-off.yaml`

## Logging and storage directives

### SecAuditEngine

**Status:** Core

**Syntax.** `SecAuditEngine On|Off|RelevantOnly`

**Default.** `Off` in ModSecurity v2 and Coraza; unset in libmodsecurity v3, which
behaves as `Off`. Normative default: `Off`.

**Semantics.** `On` writes an audit log entry for every transaction. `RelevantOnly`
writes one for transactions in which a rule carrying `auditlog` matched (the default
action list in CRS adds `auditlog` to every rule) or whose response status matches
`SecAuditLogRelevantStatus`. `Off` writes none. `ctl:auditEngine` overrides the value for
one transaction. The content and layout of an entry are defined in `10-logging.md`;
this specification never asserts on them.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecAuditLog

**Status:** Core

**Syntax.** `SecAuditLog PATH`

**Default.** None; without it audit logging is disabled even when the engine is `On`.

**Semantics.** The destination of serial audit entries, and of the index file in
concurrent mode. `PATH` is a filesystem path; engines MAY accept a `|program` pipe
(ModSecurity v2) or a URL (Coraza `https://`, Coraza ADR-0003) but those forms are
Engine-specific.

**Divergence notes.** None for a plain path.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecAuditLogFormat

**Status:** Core

**Syntax.** `SecAuditLogFormat Native|JSON`

**Default.** `Native` (all engines).

**Semantics.** Selects the serialization of audit entries: the historical multi-part
text format (`Native`) or one JSON object per entry (`JSON`). Engines MUST accept both
values. The JSON layout itself is defined in `10-logging.md` to the extent the engines
agree.

**Divergence notes.** Coraza additionally accepts `JsonLegacy` and `OCSF`
(Engine-specific, Coraza ADR-0018).

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecAuditLogParts

**Status:** Core

**Syntax.** `SecAuditLogParts LETTERS`

**Default.** `ABCFHZ` (ModSecurity v2 `apache2_config.c`, libmodsecurity v3
`audit_log.h` `m_defaultParts`, Coraza `waf.go`). Normative default: `ABCFHZ`.

**Semantics.** Which parts an audit entry contains, as a string of part letters: `A`
header, `B` request headers, `C` request body, `D` reserved, `E` intermediary response
body, `F` response headers, `G` reserved, `H` audit trailer, `I` request body without
files, `J` uploaded files information, `K` matched rules, `Z` end marker. `A` and `Z`
are mandatory. A letter outside `A`–`K` and `Z` MUST be a configuration error.
`ctl:auditLogParts` changes the parts for one transaction. Its Core value form is
relative, `+X` to add and `-X` to remove parts, which all three engines accept; the
absolute form (`ctl:auditLogParts=ABCZ`) is Extended because libmodsecurity v3 rejects
it (ADR-0006).

**Divergence notes.** All three reject unknown letters (v2 `is_valid_parts_specification`,
v3 scanner character class `[ABCDEFGHJKIZ]`, Coraza `ParseAuditLogParts`). Which parts
each engine actually fills is a `10-logging.md` matter; Coraza does not implement `D`,
`E` or `G`.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`,
`tests/engine/directives/secauditlogparts-invalid.yaml`

### SecAuditLogRelevantStatus

**Status:** Core

**Syntax.** `SecAuditLogRelevantStatus REGEX`

**Default.** None: no status is relevant until set. ModSecurity's recommended
configuration sets `"^(?:5|4(?!04))"`; Coraza's sets `"^(?:(5|4)(0|1)[0-9])$"` because
its RE2-based regex engine has no lookahead. Regex dialect differences are specified with
the `@rx` operator in Phase 3; portable values avoid lookaround.

**Semantics.** With `SecAuditEngine RelevantOnly`, a transaction whose final HTTP status
code, as a decimal string, matches `REGEX` is logged even if no rule marked it relevant.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecAuditLogStorageDir

**Status:** Core

**Syntax.** `SecAuditLogStorageDir PATH`

**Default.** None; required when `SecAuditLogType Concurrent`.

**Semantics.** The directory under which concurrent-mode audit entries are written, one
file per transaction, in the date-based subdirectory layout defined in `10-logging.md`.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecAuditLogType

**Status:** Core

**Syntax.** `SecAuditLogType Serial|Concurrent`

**Default.** `Serial` (all engines).

**Semantics.** `Serial` appends every entry to the `SecAuditLog` file. `Concurrent`
writes one file per transaction under `SecAuditLogStorageDir` and appends an index line
to `SecAuditLog`.

**Divergence notes.** libmodsecurity v3 accepts `Parallel` as an alias of `Concurrent`
and `https` for remote logging; Coraza accepts `HTTPS` and `Syslog`. Those values are
Engine-specific (ADR-0004).

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecDataDir

**Status:** Core

**Syntax.** `SecDataDir PATH`

**Default.** None.

**Semantics.** The directory where the engine keeps files that outlive a transaction:
persistent collections (`IP`, `SESSION`, `USER`, `GLOBAL`, `RESOURCE`; Extended, see
ADR-0007 in Phase 3) in ModSecurity, and any similar engine state. An engine that has no
such state MUST still accept the directive.

**Divergence notes.** Coraza has no persistent collections and accepts the directive
without effect. Both recommended configurations set it, which is why it is Core.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecDebugLog

**Status:** Core

**Syntax.** `SecDebugLog PATH`

**Default.** None: debug output goes to the host's error log or nowhere.

**Semantics.** The file that receives debug messages at or below `SecDebugLogLevel`.
Message wording is engine-specific and never asserted by this specification.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecDebugLogLevel

**Status:** Core

**Syntax.** `SecDebugLogLevel N` with `N` from 0 to 9.

**Default.** 0 in ModSecurity v2 and libmodsecurity v3; 3 in Coraza (`directives.go`).
Unspecified.

**Semantics.** 0 disables debug logging; 1 to 3 correspond to error, warning and notice
and are also mirrored to the host error log; 4 to 9 add increasing detail about rule
evaluation. A value outside 0–9 MUST be a configuration error.

**Divergence notes.** Defaults differ as listed.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecUploadDir

**Status:** Core

**Syntax.** `SecUploadDir PATH`

**Default.** None.

**Semantics.** The directory into which uploaded files are stored when
`SecUploadKeepFiles` keeps them. It MUST be on the same filesystem as `SecTmpDir` in
engines that move rather than copy; this specification does not require either.

**Divergence notes.** None known.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecUploadFileMode

**Status:** Core

**Syntax.** `SecUploadFileMode OCTAL`

**Default.** 0600 in ModSecurity v2 and Coraza; unset in libmodsecurity v3.
Unspecified.

**Semantics.** The permission bits applied to files kept under `SecUploadDir`, as an
octal number. Engines on platforms without POSIX permissions MUST accept and MAY ignore
it.

**Divergence notes.** Defaults differ as listed.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

### SecUploadKeepFiles

**Status:** Core

**Syntax.** `SecUploadKeepFiles On|Off|RelevantOnly`

**Default.** `Off` in ModSecurity v2 and Coraza; unset in libmodsecurity v3, behaving as
`Off`. Normative default: `Off`.

**Semantics.** `On` keeps every uploaded file under `SecUploadDir` after the transaction;
`Off` deletes them; `RelevantOnly` keeps them only for transactions that are audit-log
relevant. Engines MUST accept `On` and `Off`. `RelevantOnly` is Extended: see the
divergence note.

**Divergence notes.** libmodsecurity v3 rejects `RelevantOnly` ("not currently supported",
`seclang-parser.yy`); ModSecurity v2 and Coraza implement it.

**Tests.** `tests/engine/directives/logging-directives-load.yaml`

## Extended directives

Specified in outline; SHOULD be implemented. Full sections follow when an engine test can
be written for each.

### SecAuditLogDirMode

**Status:** Extended

**Syntax.** `SecAuditLogDirMode OCTAL`

**Semantics.** Permission bits for directories the concurrent audit logger creates. Default 0750 in ModSecurity v2 (`CREATEMODE_DIR` in `apache2/modsecurity.h`), 0600 in Coraza; unset in v3.

**Implemented by.** v2, v3, Coraza.

### SecAuditLogFileMode

**Status:** Extended

**Syntax.** `SecAuditLogFileMode OCTAL`

**Semantics.** Permission bits for audit files. Default 0640 in ModSecurity v2 (`CREATEMODE`) and libmodsecurity v3 (`m_defaultFilePermission`), 0600 in Coraza.

**Implemented by.** v2, v3, Coraza.

### SecCollectionTimeout

**Status:** Extended

**Syntax.** `SecCollectionTimeout SECONDS`

**Semantics.** Idle time after which a persistent collection record expires; default 3600 in v2. Meaningful only with persistent collections (ADR-0007, Phase 3).

**Implemented by.** v2, v3 (parsed), Coraza (parsed).

### SecCookieFormat

**Status:** Extended

**Syntax.** `SecCookieFormat 0|1`

**Semantics.** Cookie header syntax: 0 for Netscape-style, 1 for RFC 2965 version-1 cookies. Default 0 everywhere. Version-1 cookies are obsolete; Coraza accepts and ignores the directive (ADR-0005), which is why it is Extended although both recommended configurations set it to 0.

**Implemented by.** v2, v3 (which rejects the value `1`); Coraza parses only.

### SecCookieV0Separator

**Status:** Extended

**Syntax.** `SecCookieV0Separator CHAR`

**Semantics.** Separator between version-0 cookies; default `;`.

**Implemented by.** v2, v3.

### SecGeoLookupDb

**Status:** Extended

**Syntax.** `SecGeoLookupDb PATH`

**Semantics.** Path to a GeoIP database used by `@geoLookup` to fill the `GEO` collection. Spelled `SecGeoLookupDB` in the v2 manual; names match case-insensitively.

**Implemented by.** v2, v3.

### SecHttpBlKey

**Status:** Extended

**Syntax.** `SecHttpBlKey KEY`

**Semantics.** Project Honey Pot access key used by `@rbl` against `dnsbl.httpbl.org`.

**Implemented by.** v2, v3, Coraza.

### SecParseXmlIntoArgs

**Status:** Extended

**Syntax.** `SecParseXmlIntoArgs On|Off|OnlyArgs`

**Semantics.** Expose XML request body element values as `ARGS` so generic rules inspect them; `ctl:parseXmlIntoArgs` is the per-transaction form. Default `Off`.

**Implemented by.** v2, v3.

### SecPcreMatchLimit

**Status:** Extended

**Syntax.** `SecPcreMatchLimit N`

**Semantics.** PCRE `match_limit` for every regular expression; a hit sets `MSC_PCRE_LIMITS_EXCEEDED` (v3) or `TX:MSC_PCRE_LIMITS_EXCEEDED` (v2). Default 1500 in v2's recommended configuration. Coraza's RE2-style engine has no such limit and accepts the directive without effect.

**Implemented by.** v2, v3; Coraza parses only.

### SecPcreMatchLimitRecursion

**Status:** Extended

**Syntax.** `SecPcreMatchLimitRecursion N`

**Semantics.** PCRE `match_limit_recursion`; otherwise as `SecPcreMatchLimit`.

**Implemented by.** v2, v3; Coraza parses only.

### SecRemoteRules

**Status:** Extended

**Syntax.** `SecRemoteRules [crypto] KEY URL`

**Semantics.** Download a rule file over HTTPS at load time, sending `KEY` in the `ModSec-key` header. Coraza rejects the directive with an error rather than ignoring it.

**Implemented by.** v2, v3; Coraza errors.

### SecRemoteRulesFailAction

**Status:** Extended

**Syntax.** `SecRemoteRulesFailAction Abort|Warn`

**Semantics.** Whether a failed `SecRemoteRules` download aborts loading (default) or only warns.

**Implemented by.** v2, v3, Coraza (parsed).

### SecRuleInheritance

**Status:** Extended

**Syntax.** `SecRuleInheritance On|Off`

**Semantics.** Whether a nested configuration context (Apache `<Location>` and similar) inherits the parent's rules. Default `On`. Only meaningful where the host has nested contexts.

**Implemented by.** v2; v3 accepts `Off` and rejects `On`; Coraza does not know the name.

### SecRulePerfTime

**Status:** Extended

**Syntax.** `SecRulePerfTime MICROSECONDS`

**Semantics.** Log rules whose evaluation took longer than the threshold. Coraza accepts and ignores it.

**Implemented by.** v2, v3; Coraza parses only.

### SecRuleScript

**Status:** Extended

**Syntax.** `SecRuleScript PATH [ACTIONS]`

**Semantics.** A rule whose condition is a Lua script. Coraza accepts and ignores it (ADR-0005).

**Implemented by.** v2, v3; Coraza parses only.

### SecSensorId

**Status:** Extended

**Syntax.** `SecSensorId STRING`

**Semantics.** Identifier of this sensor, written to audit log part H. Default `default` in v2.

**Implemented by.** v2, v3, Coraza.

### SecServerSignature

**Status:** Extended

**Syntax.** `SecServerSignature STRING`

**Semantics.** Replace the `Server` response header value the host would send. Requires host support.

**Implemented by.** v2, Coraza (parsed); v3 rejects it (`seclang-parser.yy`, "not supported").

### SecTmpDir

**Status:** Extended

**Syntax.** `SecTmpDir PATH`

**Semantics.** Directory for temporary files such as spooled request bodies. Default: the system temporary directory. Coraza accepts and ignores it (ADR-0005). Extended although both recommended configurations set it, because it has no rule-visible behaviour.

**Implemented by.** v2, v3; Coraza parses only.

### SecTmpSaveUploadedFiles

**Status:** Extended

**Syntax.** `SecTmpSaveUploadedFiles On|Off`

**Semantics.** Keep uploaded files in `SecTmpDir` during the transaction so `@inspectFile` can examine them even when `SecUploadKeepFiles` is `Off`.

**Implemented by.** v2, v3.

### SecUnicodeMapFile

**Status:** Extended

**Syntax.** `SecUnicodeMapFile PATH CODEPAGE`

**Semantics.** Load a Unicode mapping table used by `t:urlDecodeUni` for `%uXXXX` sequences; the code page selects the table. Coraza has no equivalent (its `secunicodemap` key is unsupported).

**Implemented by.** v2, v3.

### SecUploadFileLimit

**Status:** Extended

**Syntax.** `SecUploadFileLimit N`

**Semantics.** Maximum number of files accepted in one multipart request; default 100 in v2. Exceeding it sets `MULTIPART_FILE_LIMIT_EXCEEDED`.

**Implemented by.** v2, v3, Coraza.

### SecWebAppId

**Status:** Extended

**Syntax.** `SecWebAppId STRING`

**Semantics.** Namespace for persistent collections and a field in audit logs so several applications behind one engine do not share `IP`/`SESSION` data. Default `default` in v2.

**Implemented by.** v2, v3, Coraza.

### SecXmlExternalEntity

**Status:** Extended

**Syntax.** `SecXmlExternalEntity On|Off`

**Semantics.** Allow the XML body processor to load external entities. Default `Off`; `On` enables XXE and is a security risk.

**Implemented by.** v2, v3.


## Deprecated directives

Engines MUST accept these names and MAY ignore them with a warning (ADR-0005). They are
Apache-era or single-engine features that no current ruleset relies on.

### SecAuditLog2

**Status:** Deprecated

**Syntax.** `SecAuditLog2 PATH`

**Semantics.** A second concurrent-mode index file.

**Implemented by.** v2, v3 (parsed).

### SecCacheTransformations

**Status:** Deprecated

**Syntax.** `SecCacheTransformations On|Off [options]`

**Semantics.** Cache transformation results across rules; experimental in v2 and never recommended.

**Implemented by.** v2; v3 rejects it; Coraza does not know the name.

### SecChrootDir

**Status:** Deprecated

**Syntax.** `SecChrootDir PATH`

**Semantics.** Chroot the Apache process after startup.

**Implemented by.** v2; v3 rejects it; Coraza does not know the name.

### SecConnEngine

**Status:** Deprecated

**Syntax.** `SecConnEngine On|Off|DetectionOnly`

**Semantics.** Connection-limiting engine using the two state-limit directives. Only v2 implements it.

**Implemented by.** v2; v3 and Coraza parse only.

### SecConnReadStateLimit

**Status:** Deprecated

**Syntax.** `SecConnReadStateLimit N [SUSPICIOUS_LIST]`

**Semantics.** Maximum concurrent connections in read state per client IP.

**Implemented by.** v2; v3, Coraza parse only.

### SecConnWriteStateLimit

**Status:** Deprecated

**Syntax.** `SecConnWriteStateLimit N [SUSPICIOUS_LIST]`

**Semantics.** Maximum concurrent connections in write state per client IP.

**Implemented by.** v2; v3, Coraza parse only.

### SecContentInjection

**Status:** Deprecated

**Syntax.** `SecContentInjection On|Off`

**Semantics.** Enable the `append` and `prepend` actions.

**Implemented by.** v2; v3 accepts `Off` and rejects `On`; Coraza does not know the name.

### SecDisableBackendCompression

**Status:** Deprecated

**Syntax.** `SecDisableBackendCompression On|Off`

**Semantics.** Remove `Accept-Encoding` on the way to the backend so response bodies can be inspected uncompressed.

**Implemented by.** v2; v3 accepts `Off` and rejects `On`; Coraza does not know the name.

### SecGsbLookupDb

**Status:** Deprecated

**Syntax.** `SecGsbLookupDb PATH`

**Semantics.** Google Safe Browsing database for `@gsbLookup`; the underlying API was retired.

**Implemented by.** v2; v3 rejects it; Coraza parses only.

### SecGuardianLog

**Status:** Deprecated

**Syntax.** `SecGuardianLog |PROGRAM`

**Semantics.** Pipe a per-request line to the `httpd-guardian` script.

**Implemented by.** v2; v3 rejects it (`seclang-parser.yy`, "not supported"); Coraza does not know the name.

### SecHashEngine

**Status:** Deprecated

**Syntax.** `SecHashEngine On|Off`

**Semantics.** Response-rewriting hash engine protecting links and forms against tampering.

**Implemented by.** v2; v3 and Coraza accept `Off` and v3 rejects `On`.

### SecHashKey

**Status:** Deprecated

**Syntax.** `SecHashKey KEY [KeyOnly|SessionID|RemoteIP]`

**Semantics.** Hash engine key material.

**Implemented by.** v2; v3 rejects it; Coraza parses only.

### SecHashMethodPm

**Status:** Deprecated

**Syntax.** `SecHashMethodPm TYPE PHRASES`

**Semantics.** Which response elements the hash engine rewrites, by phrase.

**Implemented by.** v2; v3 rejects it; Coraza parses only.

### SecHashMethodRx

**Status:** Deprecated

**Syntax.** `SecHashMethodRx TYPE REGEX`

**Semantics.** Which response elements the hash engine rewrites, by regex.

**Implemented by.** v2; v3 rejects it; Coraza parses only.

### SecHashParam

**Status:** Deprecated

**Syntax.** `SecHashParam NAME`

**Semantics.** Query parameter carrying the hash.

**Implemented by.** v2; v3 rejects it; Coraza parses only.

### SecInterceptOnError

**Status:** Deprecated

**Syntax.** `SecInterceptOnError On|Off`

**Semantics.** Deny the request when a rule-processing error occurs.

**Implemented by.** v2; v3 accepts `Off` and rejects `On`; Coraza does not know the name.

### SecReadStateLimit

**Status:** Deprecated

**Syntax.** `SecReadStateLimit N`

**Semantics.** Older name of `SecConnReadStateLimit`.

**Implemented by.** v2.

### SecRequestEncoding

**Status:** Deprecated

**Syntax.** `SecRequestEncoding ENCODING`

**Semantics.** Declared character encoding of requests; never implemented beyond parsing.

**Implemented by.** v2.

### SecStatusEngine

**Status:** Deprecated

**Syntax.** `SecStatusEngine On|Off`

**Semantics.** Report engine version and platform to the ModSecurity project at startup.

**Implemented by.** v2, v3 (parsed).

### SecStreamInBodyInspection

**Status:** Deprecated

**Syntax.** `SecStreamInBodyInspection On|Off`

**Semantics.** Expose and allow rewriting the request body as `STREAM_INPUT_BODY`.

**Implemented by.** v2; v3 rejects it; Coraza does not know the name.

### SecStreamOutBodyInspection

**Status:** Deprecated

**Syntax.** `SecStreamOutBodyInspection On|Off`

**Semantics.** Expose and allow rewriting the response body as `STREAM_OUTPUT_BODY`.

**Implemented by.** v2; v3 rejects it; Coraza does not know the name.

### SecUnicodeCodePage

**Status:** Deprecated

**Syntax.** `SecUnicodeCodePage N`

**Semantics.** Older way to select the code page now given as the second argument of `SecUnicodeMapFile`.

**Implemented by.** v2.

### SecWriteStateLimit

**Status:** Deprecated

**Syntax.** `SecWriteStateLimit N`

**Semantics.** Older name of `SecConnWriteStateLimit`.

**Implemented by.** v2.


## Engine-specific directives

Reserved names. Not specified; another engine MUST NOT give them different semantics.

### SecAuditLogPrefix

**Status:** Engine-specific

**Syntax.** `SecAuditLogPrefix STRING`

**Semantics.** libmodsecurity v3: prefix for the file names the concurrent audit logger creates.

**Implemented by.** v3.

### SecDataset

**Status:** Engine-specific

**Syntax.** `SecDataset NAME` followed by a backtick-delimited block, one entry per line

**Semantics.** Coraza (Coraza ADR-0024 lineage): an inline list consumed by `@pmFromDataset` and `@ipMatchFromDataset` without a separate file, for platforms without filesystem access. The backtick block is a lexical extension not covered by `01-lexical.md`.

**Implemented by.** Coraza.

### SecIgnoreRuleCompilationErrors

**Status:** Engine-specific

**Syntax.** `SecIgnoreRuleCompilationErrors On|Off`

**Semantics.** Coraza: continue loading when a rule fails to compile instead of aborting. Does not affect unknown directives (ADR-0005).

**Implemented by.** Coraza.

### SecRxPreFilter

**Status:** Engine-specific

**Syntax.** `SecRxPreFilter On|Off`

**Semantics.** Coraza (Coraza ADR-0050): enable a literal-substring prefilter before `@rx` evaluation. Pure optimisation; no observable behaviour.

**Implemented by.** Coraza.

