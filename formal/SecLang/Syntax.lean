import SecLang.Names
/-! AST, lexer and parser for SecLang configuration text (`spec/01-lexical.md`,
`spec/02-grammar.md`, `spec/04-directives.md`). -/
namespace SecLang

structure ConfigError where
  line : Nat
  msg : String
  file : String := ""     -- the included file the line belongs to; empty for the main configuration
  deriving Repr, BEq

abbrev Parse := Except ConfigError

def isBlank (c : Char) : Bool := c == ' ' || c == '\t'

/-- A logical line with the number of the physical line it starts on. -/
structure Line where
  num : Nat
  text : List Char

/-- Physical lines: split on LF, a trailing CR dropped (`01#lines-and-directives`). -/
def physicalLines (s : String) : List (List Char) :=
  (s.splitOn "\n").map fun l =>
    let cs := l.toList
    if cs.getLast? == some '\r' then cs.dropLast else cs

def dropTrailingBlanks (cs : List Char) : List Char := (cs.reverse.dropWhile isBlank).reverse

/-- Blank and comment lines are dropped (`01#comments`); the rest keeps its number. -/
def emitLine (l : Line) : List Line :=
  match l.text.dropWhile isBlank with
  | [] => []
  | '#' :: _ => []
  | body => [⟨l.num, dropTrailingBlanks body⟩]

/-- Logical lines: continuation joined first (`01#line-continuation`, ADR-0013), then blank
and comment lines dropped. -/
def logicalLines (s : String) : List Line :=
  go (physicalLines s) 1 none
where
  go : List (List Char) → Nat → Option Line → List Line
    | [], _, none => []
    | [], _, some l => emitLine l
    | p :: rest, n, acc =>
      let t := dropTrailingBlanks p
      let cur : Line := match acc with
        | none => ⟨n, t⟩
        | some l => ⟨l.num, l.text ++ t⟩
      if t.getLast? == some '\\' then
        go rest (n + 1) (some ⟨cur.num, cur.text.dropLast⟩)
      else emitLine cur ++ go rest (n + 1) none

/-- The directive name and its arguments (`01#quoting-and-escapes`, `02` `directive`):
bare tokens end at whitespace; a `"`-delimited argument keeps whitespace, `\"` yields `"`,
any other backslash pair is passed through unchanged. -/
def splitArgs (l : Line) : Parse (List String) := go l.text [] []
where
  err (m : String) : Parse (List String) := .error { line := l.num, msg := m }
  go : List Char → List Char → List String → Parse (List String)
    | [], [], acc => .ok acc.reverse
    | [], cur, acc => .ok (String.ofList cur.reverse :: acc).reverse
    | c :: rest, cur, acc =>
      if isBlank c then
        if cur.isEmpty then go rest [] acc else go rest [] (String.ofList cur.reverse :: acc)
      else if c == '"' && cur.isEmpty then quoted rest [] acc
      else go rest (c :: cur) acc
  quoted : List Char → List Char → List String → Parse (List String)
    | [], _, _ => err "unterminated quoted argument"
    | '\\' :: '"' :: rest, cur, acc => quoted rest ('"' :: cur) acc
    | '\\' :: c :: rest, cur, acc => quoted rest (c :: '\\' :: cur) acc
    | '"' :: rest, cur, acc =>
      match rest with
      | [] => .ok (String.ofList cur.reverse :: acc).reverse
      | c :: _ => if isBlank c then go rest [] (String.ofList cur.reverse :: acc)
                  else err "a closing quote must be followed by whitespace"
    | c :: rest, cur, acc => quoted rest (c :: cur) acc

#guard (logicalLines "a\r\nb\n\n  # c\nd \\\n  e\n# f \\\n  g\nh").map (fun l => (l.num, String.ofList l.text))
  == [(1, "a"), (2, "b"), (5, "d   e"), (9, "h")]
#guard (logicalLines "x \\").map (fun l => String.ofList l.text) == ["x"]
#guard (splitArgs ⟨1, "SecRule   ARGS_GET:a\t\"@streq 1\"     \"id:1,phase:1\"".toList⟩).toOption
  == some ["SecRule", "ARGS_GET:a", "@streq 1", "id:1,phase:1"]
#guard (splitArgs ⟨1, "SecRule ARGS \"@streq say \\\"hi\\\" now\" \"x\"".toList⟩).toOption
  == some ["SecRule", "ARGS", "@streq say \"hi\" now", "x"]
#guard (splitArgs ⟨1, "SecRule ARGS \"a\\\\b\"".toList⟩).toOption == some ["SecRule", "ARGS", "a\\\\b"]
#guard (splitArgs ⟨3, "SecRule ARGS \"unterminated".toList⟩) matches .error ⟨3, _, _⟩
#guard (splitArgs ⟨4, "SecRule \"abc\"def".toList⟩) matches .error ⟨4, _, _⟩
#guard (splitArgs ⟨1, "SecArgumentSeparator ;".toList⟩).toOption == some ["SecArgumentSeparator", ";"]

inductive Selector
  | key (k : String) | regex (re : String) | xpath (p : String)
  deriving Repr, BEq

structure Variable where
  negate : Bool
  count : Bool
  collection : String      -- canonical spelling
  selector : Option Selector
  deriving Repr, BEq

structure Operator where
  negate : Bool
  name : String            -- canonical spelling
  param : String
  deriving Repr, BEq

structure Action where
  name : String            -- canonical spelling
  value : Option String    -- quotes removed; `t:` values canonical
  deriving Repr, BEq

def err (line : Nat) (m : String) : Parse α := .error { line, msg := m }

def dropFirst (s : String) : String := String.ofList (s.toList.drop 1)
def trimBlanks (s : String) : String := String.ofList (dropTrailingBlanks (s.toList.dropWhile isBlank))

def isIdentChar (c : Char) : Bool := c.isAlphanum || c == '_'

/-- `02#variable-list`, `02#variable-selectors`: `[!|&]COLLECTION[:selector]`; the selector
is `/re/`, a key, or for `XML` an XPath expression (`05#xml`). -/
def parseVariable (line : Nat) (s : String) : Parse Variable := do
  let (negate, s) := if s.startsWith "!" then (true, dropFirst s) else (false, s)
  let (count, s) := if !negate && s.startsWith "&" then (true, dropFirst s) else (false, s)
  if (negate && s.startsWith "&") || (count && s.startsWith "!") then
    err line s!"'&' and '!' are mutually exclusive in '{s}'"
  let (name, sel) := match s.splitOn ":" with
    | [c] => (c, none)
    | c :: rest => (c, some (":".intercalate rest))
    | [] => ("", none)
  if name.isEmpty || !name.toList.all isIdentChar then err line s!"invalid variable name '{name}'"
  let some (canon, shape) := findVariable name | err line s!"unknown variable '{name}'"
  let selector ← match sel with
    | none => pure none
    | some sel =>
      if shape == .scalar then err line s!"'{canon}' is a scalar and takes no selector"
      else if canon == "XML" then pure (some (.xpath sel))
      else if sel.startsWith "/" then
        if sel.length ≥ 2 && sel.endsWith "/" then pure (some (.regex (String.ofList ((sel.toList.drop 1).dropLast))))
        else err line s!"unterminated regular expression selector '{sel}'"
      else if sel.isEmpty || sel.toList.any isBlank then err line s!"invalid selector '{sel}'"
      else pure (some (.key sel))
  return ⟨negate, count, canon, selector⟩

/-- Split a variable list on `|` outside a `/…/` selector (`02#variable-list`; `rchar` admits
`|`). An XPath selector is not delimited, so a `|` inside one still splits. -/
def splitVariables (s : String) : List String := go s.toList [] [] false
where
  go : List Char → List Char → List String → Bool → List String
    | [], cur, acc, _ => (String.ofList cur.reverse :: acc).reverse
    | ':' :: '/' :: rest, cur, acc, false => go rest ('/' :: ':' :: cur) acc true
    | '\\' :: '/' :: rest, cur, acc, true => go rest ('/' :: '\\' :: cur) acc true
    | '/' :: rest, cur, acc, true => go rest ('/' :: cur) acc false
    | '|' :: rest, cur, acc, false => go rest [] (String.ofList cur.reverse :: acc) false
    | c :: rest, cur, acc, inRe => go rest (c :: cur) acc inRe

def parseVariables (line : Nat) (s : String) : Parse (List Variable) :=
  (splitVariables s).mapM (parseVariable line)

/-- A decimal number: digits only (`String.toNat?` alone would accept `1_0`). -/
def natOf? (s : String) : Option Nat :=
  if !s.isEmpty && s.toList.all Char.isDigit then s.toNat? else none

/-- IPv4 `a.b.c.d`. -/
def isIPv4 (s : String) : Bool :=
  let parts := s.splitOn "."
  parts.length == 4 && parts.all fun p => p.length ≤ 3 && (natOf? p).any (· ≤ 255)

def isHexGroup (h : String) : Bool :=
  !h.isEmpty && h.length ≤ 4 && h.toList.all fun c => c.isAlphanum && (hexVal c.toNat.toUInt8).isSome

/-- Number of 16-bit groups in a `:`-separated run; a trailing dotted IPv4 counts as two. -/
def ipv6Groups (s : String) : Option Nat :=
  if s.isEmpty then some 0 else
  let parts := s.splitOn ":"
  match parts.getLast? with
  | some last =>
    if last.contains '.' then
      if isIPv4 last && parts.dropLast.all isHexGroup then some (parts.length + 1) else none
    else if parts.all isHexGroup then some parts.length else none
  | none => none

/-- IPv6: hex groups, at most one `::`, eight groups in all, optional IPv4 tail. -/
def isIPv6 (s : String) : Bool :=
  match s.splitOn "::" with
  | [a] => ipv6Groups a == some 8
  | [a, b] => match ipv6Groups a, ipv6Groups b with
    | some x, some y => x + y ≤ 7 && !a.contains '.'
    | _, _ => false
  | _ => false

/-- One `@ipMatch` entry: an address with an optional in-range prefix. -/
def ipEntryOk (e : String) : Bool :=
  let (addr, pfx) := match e.splitOn "/" with
    | [a] => (a, none) | [a, p] => (a, some p) | _ => ("", some "x")
  let v6 := addr.contains ':'
  let prefixOk := match pfx with | none => true | some p => (natOf? p).any (· ≤ if v6 then 128 else 32)
  (if v6 then isIPv6 addr else isIPv4 addr) && prefixOk

/-- `06#ipmatch`: every entry an address with an optional in-range prefix (ADR-0024). -/
def checkIpMatch (line : Nat) (param : String) : Parse Unit :=
  (param.splitOn ",").forM fun e =>
    if !ipEntryOk (trimBlanks e) then err line s!"invalid @ipMatch entry '{trimBlanks e}'" else pure ()

/-- `06#validatebyterange`: decimal bytes or `LOW-HIGH` ranges. -/
def checkByteRange (line : Nat) (param : String) : Parse Unit := do
  if param.isEmpty then err line "@validateByteRange needs at least one range"
  (param.splitOn ",").forM fun r => do
    let ok := match r.splitOn "-" with
      | [a] => (natOf? a).any (· ≤ 255)
      | [a, b] => match natOf? a, natOf? b with | some x, some y => x ≤ y && y ≤ 255 | _, _ => false
      | _ => false
    if !ok then err line s!"invalid @validateByteRange entry '{r}'" else pure ()

/-- `02#operator`: `[!]@name [param]`, or the implicit `@rx` parameter. -/
def parseOperator (line : Nat) (s : String) : Parse Operator := do
  let (negate, s) := if s.startsWith "!" then (true, dropFirst s) else (false, s)
  if !s.startsWith "@" then return ⟨negate, "rx", s⟩
  let body := (dropFirst s).toList
  let name := String.ofList (body.takeWhile fun c => !isBlank c)
  let param := String.ofList ((body.dropWhile fun c => !isBlank c).dropWhile isBlank)
  let some canon := findOperator name | err line s!"unknown operator '@{name}'"
  if canon == "ipMatch" then checkIpMatch line param
  if canon == "validateByteRange" then checkByteRange line param
  return ⟨negate, canon, param⟩

/-- Split an action list on commas outside single quotes (`02#action-list`); an unterminated
quote is an error (v2 `msre_parse_generic`, "Missing closing quote"). -/
def splitActions (line : Nat) (s : String) : Parse (List String) := go s.toList [] [] false
where
  go : List Char → List Char → List String → Bool → Parse (List String)
    | [], _, _, true => err line "unterminated single quote in the action list"
    | [], cur, acc, false => .ok (String.ofList cur.reverse :: acc).reverse
    | '\\' :: '\'' :: rest, cur, acc, inQ => go rest ('\'' :: '\\' :: cur) acc inQ
    | '\'' :: rest, cur, acc, inQ => go rest ('\'' :: cur) acc (!inQ)
    | ',' :: rest, cur, acc, false => go rest [] (String.ofList cur.reverse :: acc) false
    | c :: rest, cur, acc, inQ => go rest (c :: cur) acc inQ

/-- Strip one pair of single quotes and unescape `\'`. -/
def unquoteValue (v : String) : String :=
  if v.length ≥ 2 && v.startsWith "'" && v.endsWith "'" then
    (String.ofList ((v.toList.drop 1).dropLast)).replace "\\'" "'"
  else v

def phaseNumber (v : String) : Option Nat :=
  match v.toLower with
  | "1" => some 1 | "2" => some 2 | "3" => some 3 | "4" => some 4 | "5" => some 5
  | "request" => some 2 | "response" => some 4 | "logging" => some 5 | _ => none

def severityNames : List String :=
  ["emergency", "alert", "critical", "error", "warning", "notice", "info", "debug"]

def oneOf (choices : List String) (v : String) : Bool := choices.contains v.toLower

/-- `ID` or `A-B` with `A <= B` (`03#rule-exceptions`). -/
def parseRanges (line : Nat) (args : List String) : Parse (List (Nat × Nat)) :=
  args.mapM fun a => match a.splitOn "-" with
    | [x] => match natOf? x with | some n => pure (n, n) | none => err line s!"invalid rule id '{a}'"
    | [x, y] => match natOf? x, natOf? y with
      | some m, some n => if m ≤ n then pure (m, n) else err line s!"invalid range '{a}': start greater than end"
      | _, _ => err line s!"invalid range '{a}'"
    | _ => err line s!"invalid range '{a}'"

/-- Single directive arguments by kind (`04`). -/
def checkArg (line : Nat) (k : ArgKind) (v : String) : Parse Unit :=
  let enum (choices : List String) : Parse Unit :=
    if oneOf choices v then pure () else err line s!"'{v}' is not one of {choices}"
  match k with
  | .onOff => enum ["on", "off"]
  | .onOffDetectionOnly => enum ["on", "off", "detectiononly"]
  | .onOffRelevantOnly => enum ["on", "off", "relevantonly"]
  | .onOffOnlyArgs => enum ["on", "off", "onlyargs"]
  | .rejectProcessPartial => enum ["reject", "processpartial"]
  | .nativeJson => enum ["native", "json"]
  | .serialConcurrent => enum ["serial", "concurrent"]
  | .abortWarn => enum ["abort", "warn"]
  | .zeroOne => enum ["0", "1"]
  | .nat => if (natOf? v).isSome then pure () else err line s!"'{v}' is not a number"
  | .level09 => if (natOf? v).any (· ≤ 9) then pure () else err line s!"'{v}' is not a level 0-9"
  | .octal => if !v.isEmpty && v.toList.all (fun c => '0' ≤ c && c ≤ '7') then pure () else err line s!"'{v}' is not an octal mode"
  | .auditParts => if !v.isEmpty && v.toList.all (fun c => ('A' ≤ c && c ≤ 'K') || c == 'Z') then pure ()
                   else err line s!"invalid audit log parts '{v}': letters A-K and Z only"
  | .char => if v.length == 1 then pure () else err line s!"'{v}' is not a single character"
  | .text => pure ()

/-- `08#ctl` and the `ctl:` option sections; returns `option=value` with the canonical option. -/
def checkCtl (line : Nat) (v : String) : Parse String := do
  let (opt, val) := match v.splitOn "=" with
    | [o] => (o, "") | o :: rest => (o, "=".intercalate rest) | [] => ("", "")
  let some (canon, kind) := findCtl opt | err line s!"unknown ctl option '{opt}'"
  let enum (choices : List String) : Parse Unit :=
    if oneOf choices val then pure () else err line s!"ctl:{canon} takes one of {choices}, not '{val}'"
  match kind with
  | .onOff => enum ["on", "off"]
  | .onOffDetectionOnly => enum ["on", "off", "detectiononly"]
  | .onOffRelevantOnly => enum ["on", "off", "relevantonly"]
  | .onOffOnlyArgs => enum ["on", "off", "onlyargs"]
  | .parts => if val.length ≥ 2 && (val.startsWith "+" || val.startsWith "-") then checkArg line .auditParts (dropFirst val)
              else if !val.isEmpty then checkArg line .auditParts val  -- absolute form (ADR-0006)
              else err line "ctl:auditLogParts takes +LETTERS, -LETTERS or LETTERS"
  | .processor => enum ["urlencoded", "xml", "json"]
  | .nat => if (natOf? val).isSome then pure () else err line s!"ctl:{canon} takes a number"
  | .idRange => discard (parseRanges line [val])
  | .idRangeTargets => match val.splitOn ";" with
    | [r, t] => do discard (parseRanges line [r]); discard (parseVariables line t)
    | _ => err line s!"ctl:{canon} takes ID;TARGET"
  | .textTargets => match val.splitOn ";" with
    | [_, t] => discard (parseVariables line t)
    | _ => err line s!"ctl:{canon} takes REGEX;TARGET"
  | .text => pure ()
  return s!"{canon}={val}"

/-- `08#setvar`: `[!]COLL.key[=VALUE]`. -/
def checkSetvar (line : Nat) (v : String) : Parse Unit := do
  let (del, v) := if v.startsWith "!" then (true, dropFirst v) else (false, v)
  let (target, value) := match v.splitOn "=" with
    | [t] => (t, none) | t :: rest => (t, some ("=".intercalate rest)) | [] => ("", none)
  if !target.contains '.' || target.startsWith "." || target.endsWith "." then err line s!"setvar target '{target}' is not COLL.key"
  if del && value.isSome then err line s!"setvar:!{target} takes no value"

/-- One action (`02#action-list`; value kinds from `08`). -/
def parseAction (line : Nat) (raw : String) : Parse Action := do
  let s := trimBlanks raw
  let (name, value) := match s.splitOn ":" with
    | [n] => (trimBlanks n, none) | n :: rest => (trimBlanks n, some (unquoteValue (":".intercalate rest))) | [] => ("", none)
  let some (canon, kind, _) := findAction name | err line s!"unknown action '{name}'"
  let need (what : String) : Parse String := match value with
    | some v => pure v | none => err line s!"{canon} needs a value: {what}"
  match kind with
  | .none => return ⟨canon, value⟩
  | .allow => match value with
    | none => return ⟨canon, none⟩
    | some v => if oneOf ["phase", "request"] v then return ⟨canon, some v.toLower⟩ else err line "allow takes phase or request"
  | .id =>
    let v ← need "a positive integer"
    if (natOf? v).any (· > 0) then return ⟨canon, some v⟩ else err line s!"invalid id '{v}'"
  | .phase =>
    let v ← need "1-5, request, response or logging"
    if (phaseNumber v).isSome then return ⟨canon, some v⟩ else err line s!"invalid phase '{v}'"
  | .severity =>
    let v ← need "0-7 or a level name"
    if (natOf? v).any (· ≤ 7) || oneOf severityNames v then return ⟨canon, some v⟩ else err line s!"invalid severity '{v}'"
  | .nat =>
    let v ← need "a number"
    if (natOf? v).isSome then return ⟨canon, some v⟩ else err line s!"{canon} takes a number, not '{v}'"
  | .transformation =>
    let v ← need "a transformation name"
    let some t := findTransformation v | err line s!"unknown transformation '{v}'"
    return ⟨canon, some t⟩
  | .ctl =>
    let v ← need "OPTION=VALUE"
    return ⟨canon, some (← checkCtl line v)⟩
  | .setvar =>
    let v ← need "COLL.key=VALUE"
    checkSetvar line v
    return ⟨canon, some v⟩
  | .label =>
    let v ← need "a label"
    if v.isEmpty then err line s!"{canon} needs a label" else return ⟨canon, some v⟩
  | .text => return ⟨canon, value⟩

def parseActions (line : Nat) (s : String) : Parse (List Action) := do
  (← splitActions line s).mapM (parseAction line)

#guard (parseVariables 1 "ARGS_GET:a|!ARGS_GET:skip|&TX:/^x/|XML://@*").toOption ==
  some [⟨false, false, "ARGS_GET", some (.key "a")⟩, ⟨true, false, "ARGS_GET", some (.key "skip")⟩,
        ⟨false, true, "TX", some (.regex "^x")⟩, ⟨false, false, "XML", some (.xpath "//@*")⟩]
#guard (parseVariables 1 "REQUEST_URI:x") matches .error _          -- selector on a scalar
#guard (parseVariables 1 "ARGS:/unterminated") matches .error _
#guard (parseVariables 1 "NOPE") matches .error _
#guard (parseVariables 1 "!&ARGS") matches .error _
#guard (parseVariables 1 "args_get") matches .ok [⟨false, false, "ARGS_GET", none⟩]
#guard (parseOperator 1 "@streq  a b").toOption == some ⟨false, "streq", "a b"⟩
#guard (parseOperator 1 "!@PMF words.txt").toOption == some ⟨true, "pmFromFile", "words.txt"⟩
#guard (parseOperator 1 "!^abc$").toOption == some ⟨true, "rx", "^abc$"⟩
#guard (parseOperator 1 "@detectSQLi").toOption == some ⟨false, "detectSQLi", ""⟩
#guard (parseOperator 1 "@nope x") matches .error _
#guard (parseOperator 1 "@ipMatch 192.0.2.1,198.51.100.0/24,2001:db8::/32") matches .ok _
#guard (parseOperator 1 "@ipMatch 192.0.2.1,10.0.0.0/100") matches .error _
#guard (parseOperator 1 "@validateByteRange 9,10,13,32-126") matches .ok _
#guard (parseOperator 1 "@validateByteRange 9,x") matches .error _
#guard (parseActions 1 "id:1, phase:request,deny,status:403,msg:'a, b \\' c',t:LOWERCASE,ctl:ruleEngine=Off").toOption ==
  some [⟨"id", some "1"⟩, ⟨"phase", some "request"⟩, ⟨"deny", none⟩, ⟨"status", some "403"⟩,
        ⟨"msg", some "a, b ' c"⟩, ⟨"t", some "lowercase"⟩, ⟨"ctl", some "ruleEngine=Off"⟩]
#guard (parseActions 1 "id:'7',severity:'WARNING',redirect:https://x/,setvar:!tx.d,setvar:tx.e=%{tx.a},allow:phase") matches .ok _
#guard (parseActions 1 "nope") matches .error _
#guard (parseActions 1 "id:0") matches .error _
#guard (parseActions 1 "phase:6") matches .error _
#guard (parseActions 1 "severity:8") matches .error _
#guard (parseActions 1 "t:frobnicate") matches .error _
#guard (parseActions 1 "ctl:responseBodyProcessor=X") matches .error _
#guard (parseActions 1 "ctl:ruleRemoveTargetById=7150;ARGS_GET:a") matches .ok _
#guard (parseActions 1 "ctl:ruleRemoveById=200-100") matches .error _
#guard (parseActions 1 "ctl:auditLogParts=ABFHZ") matches .ok _
#guard (parseActions 1 "ctl:auditLogParts=+E") matches .ok _
#guard (parseActions 1 "ctl:auditLogParts=AXZ") matches .error _
#guard (parseActions 1 "setvar:tx") matches .error _
#guard (parseRanges 1 ["5010", "5012-5013"]).toOption == some [(5010, 5010), (5012, 5013)]
#guard (parseRanges 1 ["200-100"]) matches .error _
#guard (checkArg 1 .auditParts "AXYZ") matches .error _
#guard (checkArg 1 .auditParts "ABIJDEFHZ") matches .ok _
#guard (checkArg 1 .onOffDetectionOnly "detectiononly") matches .ok _
#guard (checkArg 1 .octal "0600") matches .ok _
#guard (checkArg 1 .octal "0699") matches .error _

structure Rule where
  line : Nat
  variables : List Variable          -- empty for SecAction
  operator : Option Operator         -- none for SecAction
  actions : List Action
  chainMember : Bool
  deriving Repr

inductive Directive
  | rule (r : Rule)
  | defaultAction (line : Nat) (phase : Nat) (actions : List Action)
  | marker (line : Nat) (label : String)
  | removeById (line : Nat) (ranges : List (Nat × Nat))
  | removeByTag (line : Nat) (regex : String)
  | removeByMsg (line : Nat) (regex : String)
  | updateActionById (line : Nat) (ranges : List (Nat × Nat)) (actions : List Action)
  | updateTargetById (line : Nat) (ranges : List (Nat × Nat)) (targets : List Variable)
  | updateTargetByTag (line : Nat) (regex : String) (targets : List Variable)
  | updateTargetByMsg (line : Nat) (regex : String) (targets : List Variable)
  | setting (line : Nat) (name : String) (args : List String)
  deriving Repr

/-- A configuration: its directives in order, `Include` expanded in place. -/
structure Config where
  directives : List Directive
  deriving Repr

/-- Parser state across directives: open chain, ids seen, default-action phases seen. -/
structure St where
  pendingChain : Bool := false
  ids : List Nat := []
  defaultPhases : List Nat := []

def metadataNames : List String := ["msg", "tag", "severity", "logdata", "rev", "ver", "accuracy", "maturity"]

def hasAction (as : List Action) (n : String) : Bool := as.any (·.name == n)
def disruptives (as : List Action) : List Action :=
  as.filter fun a => (findAction a.name).any (·.2.2 == .disruptive)

/-- Rule-level checks (`02#secrule-structure`, `03#chains`, `03#disruptive-actions`, ADR-0015). -/
def checkRule (line : Nat) (as : List Action) (st : St) : Parse St := do
  if (disruptives as).length > 1 then err line "more than one disruptive action"
  if st.pendingChain then
    for n in ["id", "phase", "skip", "skipAfter"] ++ metadataNames do
      if hasAction as n then err line s!"a chain member must not carry '{n}'"
    if !(disruptives as).isEmpty then err line "a chain member must not carry a disruptive action"
    return { st with pendingChain := hasAction as "chain" }
  else
    let some idv := (as.find? (·.name == "id")).bind (·.value) | err line "rule without an id (ADR-0015)"
    let id := (natOf? idv).getD 0
    if st.ids.contains id then err line s!"duplicate rule id {id}"
    return { st with pendingChain := hasAction as "chain", ids := id :: st.ids }

/-- `03#default-actions`, ADR-0014. -/
def checkDefaultAction (line : Nat) (as : List Action) (st : St) : Parse (Nat × St) := do
  let some pv := (as.find? (·.name == "phase")).bind (·.value) | err line "SecDefaultAction needs a phase"
  let phase := (phaseNumber pv).getD 0
  if (disruptives as).length != 1 then err line "SecDefaultAction needs exactly one disruptive action"
  for n in ["chain", "skip", "skipAfter", "t", "id"] ++ metadataNames do
    if hasAction as n then err line s!"SecDefaultAction must not carry '{n}'"
  if st.defaultPhases.contains phase then err line s!"a second SecDefaultAction for phase {phase}"
  return (phase, { st with defaultPhases := phase :: st.defaultPhases })

/-- Files matching `PATH` with one `*`, in lexicographic order; a plain path matches itself
(`01#include`). -/
def resolveInclude (files : List String) (path : String) : List String :=
  match path.splitOn "*" with
  | [_] => if files.contains path then [path] else []
  | [pre, suf] =>
    let matchesGlob (f : String) : Bool :=
      f.startsWith pre && f.endsWith suf && f.length ≥ pre.length + suf.length &&
        !((f.toList.drop pre.length).take (f.length - pre.length - suf.length)).contains '/'   -- `*` stays within one directory
    (files.filter matchesGlob).mergeSort (· < ·)
  | _ => []

/-- A file named by a file operator or `Include`, by exact name or by its basename against the
configuration's auxiliary files (`06#pmfromfile`: relative paths resolve against the
configuration file's directory). -/
def resolveFile (names : List String) (path : String) : Option String :=
  names.find? fun n => n == path || n.endsWith ("/" ++ path) || path.endsWith ("/" ++ n)

def fileOperators : List String := ["pmFromFile", "ipMatchFromFile"]

mutual
/-- One logical line into directives; an `Include` yields the included file's directives.
`depth` is the remaining nesting budget (the cap of 100 of `01#include`). -/
def parseLine (fuel : Nat) (files : List (String × String)) (depth : Nat) (st : St) (l : Line) :
    Parse (List Directive × St) :=
  match fuel with
  | 0 => err l.num "Include nesting too deep"
  | fuel + 1 => do
  let args ← splitArgs l
  let line := l.num
  let name :: rest := args | return ([], st)
  let some (canon, shape) := findDirective name | err line s!"unknown directive '{name}' (ADR-0005)"
  let arity (lo hi : Nat) : Parse Unit :=
    if rest.length < lo || rest.length > hi then
      err line s!"{canon} takes {if lo == hi then toString lo else s!"{lo} to {hi}"} argument(s), got {rest.length}"
    else pure ()
  let a (i : Nat) : String := rest.getD i ""
  match shape with
  | .rule =>
    arity 2 3
    let vars ← parseVariables line (a 0)
    let op ← parseOperator line (a 1)
    if fileOperators.contains op.name then
      if let some missing := ((op.param.splitOn " ").filter (!·.isEmpty)).find? fun p => (resolveFile (files.map (·.1)) p).isNone then
        err line s!"@{op.name}: file '{missing}' not found"
    let acts ← if rest.length == 3 then parseActions line (a 2) else pure []
    let st' ← checkRule line acts st
    return ([.rule ⟨line, vars, some op, acts, st.pendingChain⟩], st')
  | .actions =>
    arity 1 1
    let acts ← parseActions line (a 0)
    let st' ← checkRule line acts st
    return ([.rule ⟨line, [], none, acts, st.pendingChain⟩], st')
  | .defaultActions =>
    arity 1 1
    let acts ← parseActions line (a 0)
    let (phase, st') ← checkDefaultAction line acts st
    return ([.defaultAction line phase acts], st')
  | .include =>
    arity 1 1
    if depth == 0 then err line "Include nesting deeper than 100 files"
    let found := resolveInclude (files.map (·.1)) (a 0)
    if found.isEmpty then err line s!"Include: no file matches '{a 0}'"
    let mut acc : List Directive := []
    let mut s := st
    for f in found do
      let (ds, s') ← (parseText fuel files (depth - 1) s ((files.lookup f).getD "")).mapError
        fun e => if e.file.isEmpty then { e with file := f } else e
      acc := acc ++ ds
      s := s'
    return (acc, s)
  | .idRanges =>
    arity 1 1000
    return ([.removeById line (← parseRanges line rest)], st)
  | .idRangesActions =>
    arity 2 2
    let acts ← parseActions line (a 1)
    if hasAction acts "id" || hasAction acts "chain" then err line s!"{canon} must not carry id or chain"
    if (disruptives acts).length > 1 then err line s!"{canon}: more than one disruptive action"
    return ([.updateActionById line (← parseRanges line [a 0]) acts], st)
  | .idRangesTargets =>
    arity 2 2
    return ([.updateTargetById line (← parseRanges line [a 0]) (← parseVariables line (a 1))], st)
  | .regexTargets =>
    arity 2 2
    let targets ← parseVariables line (a 1)
    let d := if canon == "SecRuleUpdateTargetByTag" then Directive.updateTargetByTag line (a 0) targets
             else Directive.updateTargetByMsg line (a 0) targets
    return ([d], st)
  | .none =>
    arity 0 0
    return ([.setting line canon []], st)
  | .one k =>
    arity 1 1
    checkArg line k (a 0)
    let d := match canon with
      | "SecMarker" => Directive.marker line (a 0)
      | "SecRuleRemoveByTag" => Directive.removeByTag line (a 0)
      | "SecRuleRemoveByMsg" => Directive.removeByMsg line (a 0)
      | _ => Directive.setting line canon rest
    return ([d], st)
  | .two => arity 2 2; return ([.setting line canon rest], st)
  | .oneOrTwo => arity 1 2; return ([.setting line canon rest], st)
  | .twoOrThree => arity 2 3; return ([.setting line canon rest], st)
  | .oneOrMore => arity 1 1000; return ([.setting line canon rest], st)

/-- Every logical line of `text`, threading the state. -/
def parseText (fuel : Nat) (files : List (String × String)) (depth : Nat) (st : St) (text : String) :
    Parse (List Directive × St) :=
  match fuel with
  | 0 => err 0 "Include nesting too deep"
  | fuel + 1 => do
  let mut acc : List Directive := []
  let mut s := st
  for l in logicalLines text do
    let (ds, s') ← parseLine fuel files depth s l
    acc := acc ++ ds
    s := s'
  return (acc, s)
end

/-- A configuration with its auxiliary files (`Include` paths are looked up in `files`). -/
def parseConfig (files : List (String × String)) (text : String) : Parse Config := do
  let (ds, _) ← parseText 202 files 100 {} text   -- fuel: two per Include level, never reached before depth
  return ⟨ds⟩

#guard (parseConfig [] "SecRuleEngine On\nSecRule ARGS \"@streq 1\" \"id:1,phase:1,deny,status:403,chain\"\n  SecRule ARGS:b \"@streq 2\"\nSecAction \"id:2,phase:1,pass\"") matches .ok _
#guard (parseConfig [] "SecRule ARGS \"@streq 1\" \"phase:1,pass\"") matches .error ⟨1, _, _⟩
#guard (parseConfig [] "SecRule ARGS \"@streq 1\" \"id:1,phase:1,pass\"\nSecRule ARGS \"@streq 1\" \"id:1,phase:1,pass\"") matches .error ⟨2, _, _⟩
#guard (parseConfig [] "SecRule ARGS \"@streq 1\" \"id:1,phase:1,deny,drop\"") matches .error _
#guard (parseConfig [] "SecRule ARGS \"@streq 1\" \"id:1,phase:1,pass,chain\"\nSecRule ARGS \"@streq 2\" \"id:2\"") matches .error ⟨2, _, _⟩
#guard (parseConfig [] "SecDefaultAction \"phase:1,log\"") matches .error _
#guard (parseConfig [] "SecDefaultAction \"log,deny\"") matches .error _
#guard (parseConfig [] "SecDefaultAction \"phase:request,log,deny\"\nSecDefaultAction \"phase:2,log,pass\"") matches .error ⟨2, _, _⟩
#guard (parseConfig [] "SecDefaultAction \"phase:1,log,deny,t:none\"") matches .error _
#guard (parseConfig [] "SecFrobnicate On") matches .error _
#guard (parseConfig [] "SecRuleEngine On Off") matches .error _
#guard (parseConfig [] "SecRuleRemoveById 200-100") matches .error _
#guard (parseConfig [] "SecAuditLogParts AXYZ") matches .error _
#guard (parseConfig [("a.conf", "Include b.conf\n")] "Include a.conf") matches .error ⟨1, _, _⟩
#guard (parseConfig [("a.conf", "SecRule ARGS \"@streq 1\" \"id:5,phase:1,pass\"\n")]
          "SecRuleEngine On\nInclude a.conf\nSecRule ARGS \"@streq 1\" \"id:5,phase:1,pass\"") matches .error ⟨3, _, _⟩
#guard (parseConfig [("x1.conf", "SecRuleEngine On\n"), ("x2.conf", "SecRuleEngine Off\n")] "Include x*.conf") matches .ok _
#guard (parseConfig [] "Include none*.conf") matches .error _
#guard (parseConfig [] "SecMarker END\nSecRuleUpdateTargetById 1-3 \"!ARGS:x|REQUEST_HEADERS:y\"\nSecRuleUpdateActionById 4 \"pass\"\nSecResponseBodyMimeType text/plain text/html\nSecResponseBodyMimeTypesClear") matches .ok _

#guard (natOf? "1_0").isNone
#guard (parseActions 1 "id:1_0") matches .error _
#guard (parseConfig [] "SecRule ARGS \"@streq 1\" \"id:1,phase:1,pass,chain\"\nSecRule ARGS \"@streq 2\" \"skipAfter:X\"") matches .error ⟨2, _, _⟩
#guard (parseConfig [] "SecRuleUpdateActionById 1 \"id:5\"") matches .error _
#guard (parseConfig [] "SecRuleUpdateActionById 1-3 \"chain\"") matches .error _
#guard (parseConfig [] "SecRuleUpdateActionById 1 \"deny,pass\"") matches .error _
#guard (parseActions 1 "id:1,phase:1,msg:'abc,deny") matches .error _
#guard (parseVariables 1 "REQUEST_HEADERS:/^(?:x-a|x-b)$/|ARGS").toOption ==
  some [⟨false, false, "REQUEST_HEADERS", some (.regex "^(?:x-a|x-b)$")⟩, ⟨false, false, "ARGS", none⟩]
#guard (parseConfig [("a.conf", "SecRuleEngine On\n\n\nInclude missing.conf\n")] "SecRuleEngine On\nInclude a.conf") matches .error ⟨4, _, "a.conf"⟩
#guard (parseConfig [] "SecRule ARGS \"@streq 1\" \"id:1,phase:1,deny,drop\"") matches .error ⟨1, _, ""⟩
#guard resolveInclude ["rules/a.conf", "rules/sub/b.conf"] "rules/*.conf" == ["rules/a.conf"]
#guard (parseOperator 1 "@validateByteRange 1-255, 0") matches .error _

-- a file operator naming a file absent from the configuration is a configuration error (`06#pmfromfile`)
#guard (parseConfig [("a.txt", "x")] "SecRule ARGS \"@pmFromFile a.txt b.txt\" \"id:1,phase:1,pass\"") matches .error ⟨1, _, _⟩
#guard (parseConfig [("a.txt", "x")] "SecRule ARGS \"@pmFromFile a.txt\" \"id:1,phase:1,pass\"") matches .ok _
#guard (parseConfig [("dir/nets.txt", "x")] "SecRule ARGS \"@ipMatchF nets.txt\" \"id:1,phase:1,pass\"") matches .ok _

/-! ## Theorems for ADR-0005, ADR-0015 and ADR-0024 -/

/-- ADR-0005: a line whose directive name is not found (unknown, or Engine-specific) is a
configuration error; it is never skipped. -/
theorem unknown_directive_error (fuel : Nat) (files : List (String × String)) (depth : Nat) (st : St)
    (l : Line) {name : String} {rest : List String}
    (hargs : splitArgs l = .ok (name :: rest)) (hname : findDirective name = none) :
    ∃ e, parseLine (fuel + 1) files depth st l = .error e := by
  simp [parseLine, hargs, hname, bind, Except.bind, err]

/-- ADR-0015: a rule that starts a chain without an `id` value is a configuration error. -/
theorem rule_without_id_error (line : Nat) (as : List Action) (st : St)
    (hstart : st.pendingChain = false) (hid : (as.find? (·.name == "id")).bind (·.value) = none) :
    ∃ e, checkRule line as st = .error e := by
  unfold checkRule
  by_cases hd : (disruptives as).length > 1 <;>
    simp [hd, hstart, hid, bind, Except.bind, err]

/-- A check run over a list of entries passes exactly when every entry passes. -/
theorem forM_check_ok (l : List String) (ok : String → Bool) (msg : String → String) (line : Nat) :
    (l.forM fun e => if !ok e then err line (msg e) else (pure () : Parse Unit)) = .ok () ↔ l.all ok := by
  induction l with
  | nil => simp [pure, Except.pure]
  | cons a l ih =>
    by_cases h : ok a <;> simp_all [bind, Except.bind, err, pure, Except.pure]

/-- ADR-0024: an `@ipMatch` parameter is accepted exactly when every entry is a valid address
with an optional in-range prefix; one bad entry rejects the configuration. -/
theorem ipMatch_all_entries (line : Nat) (param : String) :
    checkIpMatch line param = .ok () ↔ (param.splitOn ",").all (ipEntryOk ∘ trimBlanks) := by
  unfold checkIpMatch
  exact forM_check_ok _ (ipEntryOk ∘ trimBlanks) _ line

#guard ipEntryOk "192.168.0.0/16" && ipEntryOk "::1" && ipEntryOk "2001:db8::/32"
#guard !ipEntryOk "192.168.0.0/33" && !ipEntryOk "10.0.0.256" && !ipEntryOk "not-an-ip"
#guard checkIpMatch 1 "10.0.0.1, 192.168.0.0/16" matches .ok _
#guard checkIpMatch 1 "10.0.0.1,bad" matches .error _

end SecLang
