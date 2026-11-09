import SecLang.Bytes
/-! Vocabulary of the specification: every defined name with its status and what the
parser needs to know about it (`spec/04`–`spec/08`). Lookup is case-insensitive (ADR-0002)
and resolves the aliases of ADR-0004; an Engine-specific name is not found (ADR-0005). -/
namespace SecLang

inductive Status | core | extended | deprecated | engineSpecific
  deriving Repr, BEq, DecidableEq

/-- Value kinds of single directive arguments (`spec/04` Syntax lines). -/
inductive ArgKind
  | onOff | onOffDetectionOnly | onOffRelevantOnly | onOffOnlyArgs | rejectProcessPartial
  | nativeJson | serialConcurrent | abortWarn | zeroOne | nat | level09 | octal | auditParts
  | char | text
  deriving Repr, BEq, DecidableEq

/-- Argument shape of a directive. -/
inductive Shape
  | none | one (k : ArgKind) | two | oneOrTwo | twoOrThree | oneOrMore
  | actions | defaultActions | idRanges | idRangesActions | idRangesTargets | regexTargets
  | rule | include
  deriving Repr, BEq

inductive VarShape | collection | scalar | unspecified
  deriving Repr, BEq, DecidableEq

/-- Value kind of an action (`spec/08` Syntax lines). -/
inductive ValueKind
  | none | allow | id | phase | severity | nat | transformation | ctl | setvar | label | text
  deriving Repr, BEq, DecidableEq

inductive ActionClass | disruptive | metadata | flow | other
  deriving Repr, BEq, DecidableEq

inductive CtlKind
  | onOff | onOffDetectionOnly | onOffRelevantOnly | onOffOnlyArgs | parts | processor | nat
  | idRange | idRangeTargets | text | textTargets
  deriving Repr, BEq, DecidableEq

/-- `spec/04-directives.md`: Deprecated directives are checked for arity only
(`spec/00-conventions.md`: accepted by the parser, may be ignored). -/
def directives : List (String × Status × Shape) := [
  ("Include", .core, .include), ("SecAction", .core, .actions),
  ("SecComponentSignature", .core, .one .text), ("SecDefaultAction", .core, .defaultActions),
  ("SecMarker", .core, .one .text), ("SecRule", .core, .rule),
  ("SecRuleRemoveById", .core, .idRanges), ("SecRuleRemoveByMsg", .extended, .one .text),
  ("SecRuleRemoveByTag", .core, .one .text), ("SecRuleUpdateActionById", .core, .idRangesActions),
  ("SecRuleUpdateTargetById", .core, .idRangesTargets), ("SecRuleUpdateTargetByMsg", .extended, .regexTargets),
  ("SecRuleUpdateTargetByTag", .core, .regexTargets),
  ("SecArgumentSeparator", .core, .one .char), ("SecArgumentsLimit", .core, .one .nat),
  ("SecRequestBodyAccess", .core, .one .onOff), ("SecRequestBodyLimit", .core, .one .nat),
  ("SecRequestBodyLimitAction", .core, .one .rejectProcessPartial), ("SecRequestBodyNoFilesLimit", .core, .one .nat),
  ("SecRequestBodyInMemoryLimit", .extended, .one .nat), ("SecRequestBodyJsonDepthLimit", .core, .one .nat),
  ("SecResponseBodyAccess", .core, .one .onOff), ("SecResponseBodyLimit", .core, .one .nat),
  ("SecResponseBodyLimitAction", .core, .one .rejectProcessPartial), ("SecResponseBodyMimeType", .core, .oneOrMore),
  ("SecResponseBodyMimeTypesClear", .core, .none), ("SecResponseBodyJsonDepthLimit", .engineSpecific, .one .nat),
  ("SecRuleEngine", .core, .one .onOffDetectionOnly),
  ("SecAuditEngine", .core, .one .onOffRelevantOnly), ("SecAuditLog", .core, .one .text),
  ("SecAuditLogFormat", .core, .one .nativeJson), ("SecAuditLogParts", .core, .one .auditParts),
  ("SecAuditLogRelevantStatus", .core, .one .text), ("SecAuditLogStorageDir", .core, .one .text),
  ("SecAuditLogType", .core, .one .serialConcurrent), ("SecDataDir", .core, .one .text),
  ("SecDebugLog", .core, .one .text), ("SecDebugLogLevel", .core, .one .level09),
  ("SecUploadDir", .core, .one .text), ("SecUploadFileMode", .core, .one .octal),
  ("SecUploadKeepFiles", .core, .one .onOffRelevantOnly),
  ("SecAuditLogDirMode", .extended, .one .octal), ("SecAuditLogFileMode", .extended, .one .octal),
  ("SecCollectionTimeout", .extended, .one .nat), ("SecCookieFormat", .extended, .one .zeroOne),
  ("SecCookieV0Separator", .extended, .one .char), ("SecGeoLookupDb", .extended, .one .text),
  ("SecHttpBlKey", .extended, .one .text), ("SecParseXmlIntoArgs", .extended, .one .onOffOnlyArgs),
  ("SecPcreMatchLimit", .extended, .one .nat), ("SecPcreMatchLimitRecursion", .extended, .one .nat),
  ("SecRemoteRules", .extended, .twoOrThree), ("SecRemoteRulesFailAction", .extended, .one .abortWarn),
  ("SecRuleInheritance", .extended, .one .onOff), ("SecRulePerfTime", .extended, .one .nat),
  ("SecRuleScript", .extended, .oneOrTwo), ("SecSensorId", .extended, .one .text),
  ("SecServerSignature", .extended, .one .text), ("SecTmpDir", .extended, .one .text),
  ("SecTmpSaveUploadedFiles", .extended, .one .onOff), ("SecUnicodeMapFile", .extended, .two),
  ("SecUploadFileLimit", .extended, .one .nat), ("SecWebAppId", .extended, .one .text),
  ("SecXmlExternalEntity", .extended, .one .onOff),
  ("SecAuditLog2", .deprecated, .one .text), ("SecCacheTransformations", .deprecated, .oneOrMore),
  ("SecChrootDir", .deprecated, .one .text), ("SecConnEngine", .deprecated, .one .text),
  ("SecConnReadStateLimit", .deprecated, .oneOrTwo), ("SecConnWriteStateLimit", .deprecated, .oneOrTwo),
  ("SecContentInjection", .deprecated, .one .text), ("SecDisableBackendCompression", .deprecated, .one .text),
  ("SecGsbLookupDb", .deprecated, .one .text), ("SecGuardianLog", .deprecated, .one .text),
  ("SecHashEngine", .deprecated, .one .text), ("SecHashKey", .deprecated, .oneOrTwo),
  ("SecHashMethodPm", .deprecated, .two), ("SecHashMethodRx", .deprecated, .two),
  ("SecHashParam", .deprecated, .one .text), ("SecInterceptOnError", .deprecated, .one .text),
  ("SecReadStateLimit", .deprecated, .one .text), ("SecRequestEncoding", .deprecated, .one .text),
  ("SecStatusEngine", .deprecated, .one .text), ("SecStreamInBodyInspection", .deprecated, .one .text),
  ("SecStreamOutBodyInspection", .deprecated, .one .text), ("SecUnicodeCodePage", .deprecated, .one .text),
  ("SecWriteStateLimit", .deprecated, .one .text),
  ("SecAuditLogPrefix", .engineSpecific, .one .text), ("SecDataset", .engineSpecific, .one .text),
  ("SecIgnoreRuleCompilationErrors", .engineSpecific, .one .text), ("SecRxPreFilter", .engineSpecific, .one .text)]

/-- `spec/05-variables.md`: the shape comes from each Core section's semantics sentence
("Collection …" or "Scalar: …"); Extended and Deprecated sections declare none. -/
def variables : List (String × Status × VarShape) := [
  ("ARGS", .core, .collection),
  ("ARGS_COMBINED_SIZE", .core, .scalar),
  ("ARGS_GET", .core, .collection),
  ("ARGS_GET_NAMES", .core, .collection),
  ("ARGS_NAMES", .core, .collection),
  ("ARGS_POST", .core, .collection),
  ("ARGS_POST_NAMES", .core, .collection),
  ("QUERY_STRING", .core, .scalar),
  ("REMOTE_ADDR", .core, .scalar),
  ("REQUEST_BASENAME", .core, .scalar),
  ("REQUEST_COOKIES", .core, .collection),
  ("REQUEST_COOKIES_NAMES", .core, .collection),
  ("REQUEST_FILENAME", .core, .scalar),
  ("REQUEST_HEADERS", .core, .collection),
  ("REQUEST_HEADERS_NAMES", .core, .collection),
  ("REQUEST_LINE", .core, .scalar),
  ("REQUEST_METHOD", .core, .scalar),
  ("REQUEST_PROTOCOL", .core, .scalar),
  ("REQUEST_URI", .core, .scalar),
  ("REQUEST_URI_RAW", .core, .scalar),
  ("UNIQUE_ID", .core, .scalar),
  ("FILES", .core, .collection),
  ("FILES_COMBINED_SIZE", .core, .scalar),
  ("FILES_NAMES", .core, .collection),
  ("INBOUND_DATA_ERROR", .core, .scalar),
  ("MULTIPART_PART_HEADERS", .core, .collection),
  ("MULTIPART_STRICT_ERROR", .core, .scalar),
  ("REQBODY_ERROR", .core, .scalar),
  ("REQBODY_ERROR_MSG", .core, .scalar),
  ("REQBODY_PROCESSOR", .core, .scalar),
  ("REQUEST_BODY", .core, .scalar),
  ("REQUEST_BODY_LENGTH", .core, .scalar),
  ("XML", .core, .collection),
  ("MATCHED_VAR", .core, .scalar),
  ("MATCHED_VAR_NAME", .core, .scalar),
  ("MATCHED_VARS", .core, .collection),
  ("TX", .core, .collection),
  ("OUTBOUND_DATA_ERROR", .core, .scalar),
  ("RESPONSE_BODY", .core, .scalar),
  ("RESPONSE_HEADERS", .core, .collection),
  ("RESPONSE_STATUS", .core, .scalar),
  ("AUTH_TYPE", .extended, .unspecified),
  ("DURATION", .extended, .unspecified),
  ("ENV", .extended, .unspecified),
  ("FILES_SIZES", .extended, .unspecified),
  ("FILES_TMP_CONTENT", .extended, .unspecified),
  ("FILES_TMPNAMES", .extended, .unspecified),
  ("FULL_REQUEST", .extended, .unspecified),
  ("FULL_REQUEST_LENGTH", .extended, .unspecified),
  ("GEO", .extended, .unspecified),
  ("GLOBAL", .extended, .unspecified),
  ("HIGHEST_SEVERITY", .extended, .unspecified),
  ("IP", .extended, .unspecified),
  ("MATCHED_VARS_NAMES", .extended, .unspecified),
  ("MODSEC_BUILD", .extended, .unspecified),
  ("MULTIPART_BOUNDARY_QUOTED", .extended, .unspecified),
  ("MULTIPART_BOUNDARY_WHITESPACE", .extended, .unspecified),
  ("MULTIPART_CRLF_LF_LINES", .extended, .unspecified),
  ("MULTIPART_DATA_AFTER", .extended, .unspecified),
  ("MULTIPART_DATA_BEFORE", .extended, .unspecified),
  ("MULTIPART_FILE_LIMIT_EXCEEDED", .extended, .unspecified),
  ("MULTIPART_FILENAME", .extended, .unspecified),
  ("MULTIPART_HEADER_FOLDING", .extended, .unspecified),
  ("MULTIPART_INVALID_HEADER_FOLDING", .extended, .unspecified),
  ("MULTIPART_INVALID_PART", .extended, .unspecified),
  ("MULTIPART_INVALID_QUOTING", .extended, .unspecified),
  ("MULTIPART_LF_LINE", .extended, .unspecified),
  ("MULTIPART_MISSING_SEMICOLON", .extended, .unspecified),
  ("MULTIPART_NAME", .extended, .unspecified),
  ("MULTIPART_UNMATCHED_BOUNDARY", .extended, .unspecified),
  ("PATH_INFO", .extended, .unspecified),
  ("REMOTE_HOST", .extended, .unspecified),
  ("REMOTE_PORT", .extended, .unspecified),
  ("REMOTE_USER", .extended, .unspecified),
  ("REQBODY_PROCESSOR_ERROR", .extended, .unspecified),
  ("REQBODY_PROCESSOR_ERROR_MSG", .extended, .unspecified),
  ("RESOURCE", .extended, .unspecified),
  ("RESPONSE_CONTENT_LENGTH", .extended, .unspecified),
  ("RESPONSE_CONTENT_TYPE", .extended, .unspecified),
  ("RESPONSE_HEADERS_NAMES", .extended, .unspecified),
  ("RESPONSE_PROTOCOL", .extended, .unspecified),
  ("RULE", .extended, .unspecified),
  ("SERVER_ADDR", .extended, .unspecified),
  ("SERVER_NAME", .extended, .unspecified),
  ("SERVER_PORT", .extended, .unspecified),
  ("SESSION", .extended, .unspecified),
  ("SESSIONID", .extended, .unspecified),
  ("STATUS_LINE", .extended, .unspecified),
  ("TIME", .extended, .unspecified),
  ("TIME_DAY", .extended, .unspecified),
  ("TIME_EPOCH", .extended, .unspecified),
  ("TIME_HOUR", .extended, .unspecified),
  ("TIME_MIN", .extended, .unspecified),
  ("TIME_MON", .extended, .unspecified),
  ("TIME_SEC", .extended, .unspecified),
  ("TIME_WDAY", .extended, .unspecified),
  ("TIME_YEAR", .extended, .unspecified),
  ("URLENCODED_ERROR", .extended, .unspecified),
  ("USER", .extended, .unspecified),
  ("USERID", .extended, .unspecified),
  ("WEBAPPID", .extended, .unspecified),
  ("MULTIPART_CRLF_LINE", .deprecated, .unspecified),
  ("PERF_ALL", .deprecated, .unspecified),
  ("PERF_COMBINED", .deprecated, .unspecified),
  ("PERF_GC", .deprecated, .unspecified),
  ("PERF_LOGGING", .deprecated, .unspecified),
  ("PERF_PHASE1", .deprecated, .unspecified),
  ("PERF_PHASE2", .deprecated, .unspecified),
  ("PERF_PHASE3", .deprecated, .unspecified),
  ("PERF_PHASE4", .deprecated, .unspecified),
  ("PERF_PHASE5", .deprecated, .unspecified),
  ("PERF_RULES", .deprecated, .unspecified),
  ("PERF_SREAD", .deprecated, .unspecified),
  ("PERF_SWRITE", .deprecated, .unspecified),
  ("SCRIPT_BASENAME", .deprecated, .unspecified),
  ("SCRIPT_FILENAME", .deprecated, .unspecified),
  ("SCRIPT_GID", .deprecated, .unspecified),
  ("SCRIPT_GROUPNAME", .deprecated, .unspecified),
  ("SCRIPT_MODE", .deprecated, .unspecified),
  ("SCRIPT_UID", .deprecated, .unspecified),
  ("SCRIPT_USERNAME", .deprecated, .unspecified),
  ("SDBM_DELETE_ERROR", .deprecated, .unspecified),
  ("STREAM_INPUT_BODY", .deprecated, .unspecified),
  ("STREAM_OUTPUT_BODY", .deprecated, .unspecified),
  ("USERAGENT_IP", .deprecated, .unspecified),
  ("WEBSERVER_ERROR_LOG", .deprecated, .unspecified),
  ("ARGS_PATH", .engineSpecific, .unspecified),
  ("ARGUMENTS_LIMIT_REACHED", .engineSpecific, .unspecified),
  ("JSON", .engineSpecific, .unspecified),
  ("MSC_PCRE_ERROR", .engineSpecific, .unspecified),
  ("MSC_PCRE_LIMITS_EXCEEDED", .engineSpecific, .unspecified),
  ("MULTIPART_DUPLICATE_PART_HEADER", .engineSpecific, .unspecified),
  ("MULTIPART_FILENAME_CHARSET", .engineSpecific, .unspecified),
  ("MULTIPART_FILENAME_LANGUAGE", .engineSpecific, .unspecified),
  ("REQUEST_XML", .engineSpecific, .unspecified),
  ("RES_BODY_ERROR", .engineSpecific, .unspecified),
  ("RES_BODY_ERROR_MSG", .engineSpecific, .unspecified),
  ("RES_BODY_PROCESSOR", .engineSpecific, .unspecified),
  ("RES_BODY_PROCESSOR_ERROR", .engineSpecific, .unspecified),
  ("RES_BODY_PROCESSOR_ERROR_MSG", .engineSpecific, .unspecified),
  ("RESPONSE_ARGS", .engineSpecific, .unspecified),
  ("RESPONSE_XML", .engineSpecific, .unspecified),
  ("STATUS", .engineSpecific, .unspecified),
  ("URI_PARSE_ERROR", .engineSpecific, .unspecified)]

/-- `spec/06-operators.md`. -/
def operators : List (String × Status) := [
  ("beginsWith", .core), ("contains", .core), ("detectSQLi", .core), ("detectXSS", .core),
  ("endsWith", .core), ("eq", .core), ("ge", .core), ("gt", .core), ("ipMatch", .core), ("le", .core),
  ("lt", .core), ("pm", .core), ("pmFromFile", .core), ("rx", .core), ("streq", .core),
  ("unconditionalMatch", .core), ("validateByteRange", .core), ("validateUrlEncoding", .core),
  ("validateUtf8Encoding", .core), ("within", .core),
  ("containsWord", .extended), ("fuzzyHash", .extended), ("geoLookup", .extended), ("inspectFile", .extended),
  ("ipMatchFromFile", .extended), ("noMatch", .extended), ("rbl", .extended), ("strmatch", .extended),
  ("validateDTD", .extended), ("validateHash", .extended), ("validateSchema", .extended),
  ("verifyCC", .extended), ("verifyCPF", .extended), ("verifySSN", .extended),
  ("rsub", .deprecated), ("gsbLookup", .deprecated),
  ("ipMatchFromDataset", .engineSpecific), ("pmFromDataset", .engineSpecific), ("restpath", .engineSpecific),
  ("rxGlobal", .engineSpecific), ("validateNid", .engineSpecific), ("verifySVNR", .engineSpecific)]

/-- ADR-0004 aliases, lower-cased alias → canonical. -/
def operatorAliases : List (String × String) := [("pmf", "pmFromFile"), ("ipmatchf", "ipMatchFromFile")]
def transformationAliases : List (String × String) :=
  [("normalizepath", "normalisePath"), ("normalizepathwin", "normalisePathWin")]

/-- `spec/08-actions.md`: value kind and class (`03#disruptive-actions`, `03#chains`). -/
def actions : List (String × Status × ValueKind × ActionClass) := [
  ("allow", .core, .allow, .disruptive), ("auditlog", .core, .none, .other), ("block", .core, .none, .disruptive),
  ("capture", .core, .none, .other), ("chain", .core, .none, .flow), ("ctl", .core, .ctl, .other),
  ("deny", .core, .none, .disruptive), ("drop", .core, .none, .disruptive), ("id", .core, .id, .other),
  ("log", .core, .none, .other), ("logdata", .core, .text, .metadata), ("msg", .core, .text, .metadata),
  ("multiMatch", .core, .none, .other), ("noauditlog", .core, .none, .other), ("nolog", .core, .none, .other),
  ("pass", .core, .none, .disruptive), ("phase", .core, .phase, .other), ("redirect", .core, .text, .disruptive),
  ("setvar", .core, .setvar, .other), ("severity", .core, .severity, .metadata), ("skipAfter", .core, .label, .flow),
  ("status", .core, .nat, .other), ("t", .core, .transformation, .other), ("tag", .core, .text, .metadata),
  ("ver", .core, .text, .metadata),
  ("accuracy", .extended, .nat, .metadata), ("exec", .extended, .text, .other), ("expirevar", .extended, .text, .other),
  ("initcol", .extended, .text, .other), ("maturity", .extended, .nat, .metadata), ("rev", .extended, .text, .metadata),
  ("setenv", .extended, .text, .other), ("setrsc", .extended, .text, .other), ("setsid", .extended, .text, .other),
  ("setuid", .extended, .text, .other), ("skip", .extended, .nat, .flow), ("xmlns", .extended, .text, .other),
  ("append", .deprecated, .text, .other), ("deprecatevar", .deprecated, .text, .other), ("marker", .deprecated, .text, .other),
  ("pause", .deprecated, .text, .other), ("prepend", .deprecated, .text, .other), ("proxy", .deprecated, .text, .other),
  ("sanitizeArg", .extended, .text, .other), ("sanitizeMatched", .extended, .none, .other),
  ("sanitizeMatchedBytes", .extended, .text, .other), ("sanitizeRequestHeader", .extended, .text, .other),
  ("sanitizeResponseHeader", .extended, .text, .other)]

/-- `spec/08-actions.md`, index of ctl options. -/
def ctlOptions : List (String × Status × CtlKind) := [
  ("auditEngine", .core, .onOffRelevantOnly), ("auditLogParts", .core, .parts),
  ("forceRequestBodyVariable", .core, .onOff), ("requestBodyAccess", .core, .onOff),
  ("requestBodyProcessor", .core, .processor), ("ruleEngine", .core, .onOffDetectionOnly),
  ("ruleRemoveById", .core, .idRange), ("ruleRemoveByTag", .core, .text),
  ("ruleRemoveTargetById", .core, .idRangeTargets), ("ruleRemoveTargetByTag", .core, .textTargets),
  ("debugLogLevel", .extended, .nat), ("parseXmlIntoArgs", .extended, .onOffOnlyArgs),
  ("requestBodyLimit", .extended, .nat), ("responseBodyAccess", .extended, .onOff),
  ("responseBodyLimit", .extended, .nat), ("ruleRemoveByMsg", .extended, .text),
  ("ruleRemoveTargetByMsg", .extended, .textTargets),
  ("hashEnforcement", .deprecated, .text), ("hashEngine", .deprecated, .text),
  ("forceResponseBodyVariable", .engineSpecific, .text), ("responseBodyProcessor", .engineSpecific, .text)]

/-- `spec/07-transformations.md`. -/
def transformations : List (String × Status) := [
  ("base64Decode", .core), ("cmdLine", .core), ("compressWhitespace", .core), ("cssDecode", .core),
  ("escapeSeqDecode", .core), ("hexEncode", .core), ("htmlEntityDecode", .core), ("jsDecode", .core),
  ("length", .core), ("lowercase", .core), ("none", .core), ("normalisePath", .core), ("normalisePathWin", .core),
  ("removeCommentsChar", .core), ("removeNulls", .core), ("removeWhitespace", .core), ("replaceComments", .core),
  ("sha1", .core), ("uppercase", .core), ("urlDecodeUni", .core), ("utf8toUnicode", .core),
  ("base64DecodeExt", .extended), ("base64Encode", .extended), ("hexDecode", .extended), ("md5", .extended),
  ("parityEven7bit", .extended), ("parityOdd7bit", .extended), ("parityZero7bit", .extended),
  ("removeComments", .extended), ("replaceNulls", .extended), ("sqlHexDecode", .extended), ("trim", .extended),
  ("trimLeft", .extended), ("trimRight", .extended), ("urlDecode", .extended), ("urlEncode", .extended)]

/-- The row whose name equals `s` ignoring case, unless its status is Engine-specific. -/
def findRow (rows : List (String × Status × α)) (s : String) : Option (String × α) :=
  let l := s.toLower
  match rows.find? fun r => r.1.toLower == l with
  | some (n, st, x) => if st == .engineSpecific then none else some (n, x)
  | none => none

def findDirective (s : String) : Option (String × Shape) := findRow directives s
def findVariable (s : String) : Option (String × VarShape) := findRow variables s

def findNamed (rows : List (String × Status)) (aliases : List (String × String)) (s : String) : Option String :=
  let s := (aliases.lookup s.toLower).getD s
  (findRow (rows.map fun (n, st) => (n, st, ())) s).map (·.1)

def findOperator : String → Option String := findNamed operators operatorAliases
def findTransformation : String → Option String := findNamed transformations transformationAliases
def findAction (s : String) : Option (String × ValueKind × ActionClass) := findRow actions s
def findCtl (s : String) : Option (String × CtlKind) := findRow ctlOptions s

#guard (findDirective "secrule").map (·.1) == some "SecRule"
#guard (findDirective "SecFrobnicate").isNone
#guard (findDirective "SecRxPreFilter").isNone            -- Engine-specific
#guard (findDirective "SecHashEngine").map (·.1) == some "SecHashEngine"   -- Deprecated, accepted
#guard (findVariable "args_get") == some ("ARGS_GET", .collection)
#guard (findVariable "REQUEST_URI") == some ("REQUEST_URI", .scalar)
#guard (findVariable "JSON").isNone
#guard findOperator "PMF" == some "pmFromFile"
#guard findOperator "ipmatchf" == some "ipMatchFromFile"
#guard (findOperator "restpath").isNone
#guard (findAction "DENY").map (·.1) == some "deny"
#guard (findAction "deny").map (·.2.2) == some ActionClass.disruptive
#guard (findAction "msg").map (·.2.2) == some ActionClass.metadata
#guard (findAction "SanitizeResponseHeader").map (·.1) == some "sanitizeResponseHeader"
#guard (findAction "sanitiseArg").isNone                -- not an alias (ADR-0033)
#guard (findCtl "RULEENGINE").map (·.1) == some "ruleEngine"
#guard (findCtl "responseBodyProcessor").isNone
#guard findTransformation "normalizePath" == some "normalisePath"
#guard findTransformation "NONE" == some "none"

end SecLang
