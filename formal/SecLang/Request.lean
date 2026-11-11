import Lean.Data.Json
import SecLang.Syntax
import SecLang.Transformations
open Lean (Json)
/-! The variable store of one transaction, populated from the request and response per
`spec/05-variables.md` and `spec/09-body-processors.md` (URL-encoded and multipart bodies). -/
namespace SecLang

structure Member where
  key : String
  value : ByteArray

/-- Canonical collection name → members; a scalar is one member with the empty key. -/
abbrev Store := List (String × List Member)

def Store.get (st : Store) (coll : String) : List Member := (st.lookup coll).getD []
def Store.set (st : Store) (coll : String) (ms : List Member) : Store := (coll, ms) :: st.filter (·.1 != coll)

def text (s : String) : ByteArray := s.toUTF8
/-- A configuration string in the store's key convention (Latin-1 form of its bytes). -/
def latin (s : String) : String := ofBytes s.toUTF8
def scalar (v : ByteArray) : List Member := [⟨"", v⟩]

structure Request where
  method : String := "GET"
  uri : String := "/"
  version : String := "HTTP/1.1"
  headers : List (String × String) := []
  body : Option String := none
  remoteAddr : String := "127.0.0.1"

structure Response where
  status : Nat := 200
  headers : List (String × String) := []
  body : String := ""

/-- Configuration-level settings the store depends on (`04`). The response MIME set has no
specified default (`04#secresponsebodymimetype`): none until set. -/
inductive LimitAction | reject | processPartial
  deriving Repr, BEq, DecidableEq

structure Settings where
  argSep : Char := '&'
  argsLimit : Option Nat := none
  requestBodyAccess : Bool := false
  responseBodyAccess : Bool := false
  mimeTypes : List String := []
  requestBodyLimit : Option Nat := none
  requestBodyLimitAction : LimitAction := .reject
  responseBodyLimit : Option Nat := none
  responseBodyLimitAction : LimitAction := .reject   -- unspecified default (`04`); v2's
  jsonDepthLimit : Nat := 10000

/-- A body against its limit (`04#secrequestbodylimitaction`, `04#secresponsebodylimitaction`):
the body to process, whether the `*_DATA_ERROR` flag is set, and the status of a `Reject`
interruption (413 request, 500 response: the v2 and Coraza values; the spec leaves it open).
`enforce` is false in `DetectionOnly`, where `Reject` neither interrupts nor truncates but
still sets the flag (v2 `apache2/mod_security2.c`, the `is_enabled != MODSEC_DETECTION_ONLY`
test and the `inbound_error = 1` branch; Coraza `internal/corazawaf/transaction.go` sets
`inboundDataError` before choosing the action). -/
def applyLimit (limit : Option Nat) (action : LimitAction) (enforce : Bool) (status : Nat) (body : String) :
    String × Bool × Option Nat :=
  match limit with
  | none => (body, false, none)
  | some n =>
    let bytes := text body
    if bytes.size ≤ n then (body, false, none)
    else if action == .reject then (body, !enforce, if enforce then some status else none)
    else
      let cut := bytes.extract 0 n
      (if h : cut.IsValidUTF8 then String.fromUTF8 cut h else String.ofList (body.toList.take n), true, none)

def headerValue (hs : List (String × String)) (name : String) : Option String :=
  (hs.find? fun (k, _) => k.toLower == name.toLower).map (·.2)

/-- Whether the response body is buffered (`04#secresponsebodyaccess`, `04#secresponsebodymimetype`). -/
def responseBuffered (st : Settings) (rs : Response) : Bool :=
  let ct := (headerValue rs.headers "Content-Type").map fun c => trimBlanks ((c.splitOn ";").headD "")
  st.responseBodyAccess && ct.any st.mimeTypes.contains

def limitArgs (lim : Option Nat) (ms : List Member) : List Member :=
  match lim with | some n => ms.take n | none => ms

/-- `name=value` pairs split on `sep`, both sides URL-decoded (`05#args`, `09#urlencoded`: an
empty pair is ignored), capped by `SecArgumentsLimit`. -/
def parseArgs (sep : Char) (lim : Option Nat) (s : String) : List Member :=
  if s.isEmpty then [] else
  limitArgs lim <| ((s.splitOn (String.singleton sep)).filter (!·.isEmpty)).map fun pair =>
    let (n, v) := match pair.splitOn "=" with
      | [n] => (n, "") | n :: rest => (n, "=".intercalate rest) | [] => ("", "")
    ⟨ofBytes (urlDecode (text n)), urlDecode (text v)⟩

def namesOf (ms : List Member) : List Member := ms.map fun m => ⟨m.key, bytesOf m.key⟩
def combinedSize (ms : List Member) : Nat := ms.foldl (fun n m => n + (bytesOf m.key).size + m.value.size) 0
def natText (n : Nat) : List Member := scalar (text (toString n))

/-- Phase 1 store (`05`): request line, headers, cookies, query arguments. -/
def phase1Store (st : Settings) (r : Request) : Store :=
  let (path, query) := match r.uri.splitOn "?" with
    | [p] => (p, "") | p :: rest => (p, "?".intercalate rest) | [] => ("", "")
  let base := (path.splitOn "/").getLast?.getD path
  let getArgs := parseArgs st.argSep st.argsLimit query
  let headers := r.headers.map fun (k, v) => Member.mk (latin k) (text (trimBlanks v))
  let cookies := (r.headers.filter fun (k, _) => k.toLower == "cookie").flatMap fun (_, v) =>
    (v.splitOn ";").filterMap fun c =>
      let c := trimBlanks c
      if c.isEmpty then none else some (match c.splitOn "=" with
        | [n] => Member.mk (latin (trimBlanks n)) (text "")
        | n :: rest => Member.mk (latin (trimBlanks n)) (text (trimBlanks ("=".intercalate rest)))
        | [] => Member.mk "" (text ""))
  [("REQUEST_METHOD", scalar (text r.method)), ("REQUEST_URI", scalar (text r.uri)),
   ("REQUEST_URI_RAW", scalar (text r.uri)), ("REQUEST_FILENAME", scalar (text path)),
   ("REQUEST_BASENAME", scalar (text base)), ("QUERY_STRING", scalar (text query)),
   ("REQUEST_PROTOCOL", scalar (text r.version)),
   ("REQUEST_LINE", scalar (text s!"{r.method} {r.uri} {r.version}")),
   ("REMOTE_ADDR", scalar (text r.remoteAddr)), ("UNIQUE_ID", scalar (text "seclang-model")),
   ("REQUEST_HEADERS", headers), ("REQUEST_HEADERS_NAMES", namesOf headers),
   ("REQUEST_COOKIES", cookies), ("REQUEST_COOKIES_NAMES", namesOf cookies),
   ("ARGS_GET", getArgs), ("ARGS_GET_NAMES", namesOf getArgs), ("ARGS", getArgs),
   ("ARGS_NAMES", namesOf getArgs), ("ARGS_COMBINED_SIZE", natText (combinedSize getArgs)),
   ("REQUEST_BODY_LENGTH", natText 0), ("REQBODY_PROCESSOR", scalar (text "")),
   -- the model has no clock: no time passes, so `DURATION` is always 0 ms (ADR-0019)
   ("DURATION", natText 0)]

/-- Body processor from the `Content-Type` prefix (`09#processor-selection`) unless a
phase 1 `ctl:requestBodyProcessor` chose one. -/
def selectProcessor (override : Option String) (contentType : Option String) : String :=
  match override with
  | some p => p.toUpper
  | none => match contentType with
    | some ct =>
      if ct.toLower.startsWith "application/x-www-form-urlencoded" then "URLENCODED"
      else if ct.toLower.startsWith "multipart/form-data" then "MULTIPART" else ""
    | none => ""

structure Part where
  name : String
  filename : Option String
  headers : String
  content : ByteArray

/-- Split on `;` outside double quotes. -/
def splitParams (s : String) : List String :=
  go s.toList false [] []
where
  go : List Char → Bool → List Char → List String → List String
    | [], _, cur, acc => (String.ofList cur.reverse :: acc).reverse
    | '"' :: rest, inQ, cur, acc => go rest (!inQ) ('"' :: cur) acc
    | ';' :: rest, inQ, cur, acc => if inQ then go rest inQ (';' :: cur) acc else go rest inQ [] (String.ofList cur.reverse :: acc)
    | c :: rest, inQ, cur, acc => go rest inQ (c :: cur) acc

/-- A `key=value` parameter of a `;`-separated header value, quotes removed. -/
def headerParam (v : String) (key : String) : Option String :=
  ((splitParams v).map trimBlanks).findSome? fun p =>
    match p.splitOn "=" with
    | k :: rest@(_ :: _) =>
      if (trimBlanks k).toLower == key.toLower then
        let val := "=".intercalate rest
        some (if val.length ≥ 2 && val.startsWith "\"" && val.endsWith "\"" then String.ofList ((val.toList.drop 1).dropLast) else val)
      else none
    | _ => none

/-- One part from its header lines and content lines (each with its line ending). -/
def mkPart (hdrs : List String) (content : List (String × String)) : Part :=
  let disposition := (hdrs.find? fun l => l.toLower.startsWith "content-disposition:").map fun l =>
    dropFirst (String.ofList (l.toList.dropWhile (· != ':')))
  -- the last content line's ending belongs to the delimiter that follows it
  let body := String.join ((content.dropLast.map fun (l, e) => l ++ e) ++ (content.getLast?.map (·.1)).toList)
  { name := (disposition.bind (headerParam · "name")).getD "", filename := disposition.bind (headerParam · "filename"),
    headers := "\r\n".intercalate hdrs, content := text body }

/-- Lines with their endings (`"\r\n"`, `"\n"`, or `""` for an unterminated last line). -/
def splitLines (s : String) : List (String × String) :=
  match (s.splitOn "\n").reverse with
  | [] => []
  | last :: initRev =>
    let ends := initRev.reverse.map fun l =>
      if l.endsWith "\r" then (String.ofList l.toList.dropLast, "\r\n") else (l, "\n")
    ends ++ (if last.isEmpty then [] else [(last, "")])

/-- RFC 7578 (`09#multipart`): the parts and whether an anomaly was seen (ModSecurity v2
`apache2/msc_multipart.c`): data before the first boundary or after the closing one, a
boundary line carrying other characters, a bare LF ending on a boundary or header line, or
no closing delimiter. A bare LF inside part content is data, not an anomaly. -/
def parseMultipart (boundary : String) (body : String) : List Part × Bool :=
  let delim := "--" ++ boundary
  -- state: 0 preamble, 1 headers, 2 content, 3 after the closing delimiter
  let rec go : List (String × String) → Nat → List String → List (String × String) → List Part → Bool → List Part × Bool
    | [], state, hdrs, content, parts, bad =>
      let parts := if state == 1 || state == 2 then parts ++ [mkPart hdrs content] else parts
      (parts, bad || state != 3)
    | (l, e) :: rest, state, hdrs, content, parts, bad =>
      let flush := if state == 1 || state == 2 then parts ++ [mkPart hdrs content] else parts
      if l.startsWith delim && state != 3 then
        let tail := trimBlanks (String.ofList (l.toList.drop delim.length))
        let bad := bad || e == "\n" || tail.length + delim.length != l.length
        if tail.isEmpty then go rest 1 [] [] flush bad
        else if tail == "--" then go rest 3 [] [] flush bad
        else match state with  -- not a boundary: content stays visible, the anomaly is recorded
          | 2 => go rest 2 hdrs (content ++ [(l, e)]) parts true
          | _ => go rest state hdrs content parts true
      else match state with
        | 0 => go rest 0 hdrs content parts true
        | 1 => if l.isEmpty then go rest 2 hdrs content parts bad else go rest 1 (hdrs ++ [l]) content parts (bad || e == "\n")
        | 2 => go rest 2 hdrs (content ++ [(l, e)]) parts bad
        | _ => go rest 3 hdrs content parts (bad || !l.isEmpty)
  go (splitLines body) 0 [] [] [] false

/-! Minimal JSON reader (RFC 8259) for `09#json`: leaves in document order, each number kept
as written (its text is the member value), strings decoded through `Json.parse`, depth
counting every object or array entered (`04#secrequestbodyjsondepthlimit`). Names follow
ModSecurity v2 (`apache2/msc_json.c`): the key path joined by `.`, array elements under the
containing key, `array` at the top level; `null` is the empty string. Names are not
specified (ADR-0020). -/
namespace JsonRead

def ws : List Char → List Char := List.dropWhile fun c => c == ' ' || c == '\t' || c == '\n' || c == '\r'

/-- The characters of a string token after its opening quote, escapes kept, and the rest. -/
def strTok : List Char → List Char → Except String (List Char × List Char)
  | [], _ => .error "unterminated string"
  | '\\' :: c :: rest, acc => strTok rest (c :: '\\' :: acc)
  | '"' :: rest, acc => .ok (acc.reverse, rest)
  | c :: rest, acc => strTok rest (c :: acc)

def decodeStr (tok : List Char) : Except String String :=
  match Json.parse (String.ofList ('"' :: tok ++ ['"'])) with
  | .ok (.str s) => .ok s
  | _ => .error s!"invalid string {String.ofList tok}"

def isNumChar (c : Char) : Bool := c.isDigit || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E'

abbrev Leaves := List (String × String)

mutual
def value (fuel limit depth : Nat) (name : String) (cs : List Char) : Except String (Leaves × List Char) :=
  match fuel with
  | 0 => .error "document too deep"
  | fuel + 1 => do
  match ws cs with
  | '{' :: rest =>
    if depth + 1 > limit then throw s!"depth limit ({limit}) exceeded"
    members fuel limit (depth + 1) name (ws rest) true
  | '[' :: rest =>
    if depth + 1 > limit then throw s!"depth limit ({limit}) exceeded"
    elements fuel limit (depth + 1) (if name.isEmpty then "array" else name) (ws rest) true
  | '"' :: rest =>
    let (tok, rest) ← strTok rest []
    return ([(name, ← decodeStr tok)], rest)
  | 't' :: 'r' :: 'u' :: 'e' :: rest => return ([(name, "true")], rest)
  | 'f' :: 'a' :: 'l' :: 's' :: 'e' :: rest => return ([(name, "false")], rest)
  | 'n' :: 'u' :: 'l' :: 'l' :: rest => return ([(name, "")], rest)
  | cs' =>
    let tok := cs'.takeWhile isNumChar
    if tok.isEmpty then throw "unexpected character"
    match Json.parse (String.ofList tok) with
    | .ok (.num _) => return ([(name, String.ofList tok)], cs'.drop tok.length)
    | _ => throw s!"invalid number {String.ofList tok}"

def members (fuel limit depth : Nat) (prefix_ : String) (cs : List Char) (first : Bool) : Except String (Leaves × List Char) :=
  match fuel with
  | 0 => .error "document too deep"
  | fuel + 1 => do
  match cs with
  | '}' :: rest => if first then return ([], rest) else throw "trailing comma"
  | '"' :: rest =>
    let (tok, rest) ← strTok rest []
    let k ← decodeStr tok
    match ws rest with
    | ':' :: rest =>
      let (vs, rest) ← value fuel limit depth (if prefix_.isEmpty then k else prefix_ ++ "." ++ k) rest
      match ws rest with
      | ',' :: rest => let (more, rest) ← members fuel limit depth prefix_ (ws rest) false; return (vs ++ more, rest)
      | '}' :: rest => return (vs, rest)
      | _ => throw "expected , or }"
    | _ => throw "expected :"
  | _ => throw "expected a string key"

def elements (fuel limit depth : Nat) (name : String) (cs : List Char) (first : Bool) : Except String (Leaves × List Char) :=
  match fuel with
  | 0 => .error "document too deep"
  | fuel + 1 => do
  match cs with
  | ']' :: rest => if first then return ([], rest) else throw "trailing comma"
  | _ =>
    let (vs, rest) ← value fuel limit depth name cs
    match ws rest with
    | ',' :: rest => let (more, rest) ← elements fuel limit depth name (ws rest) false; return (vs ++ more, rest)
    | ']' :: rest => return (vs, rest)
    | _ => throw "expected , or ]"
end

end JsonRead

/-- `09#json`: the members, or the `REQBODY_ERROR_MSG` text. -/
def parseJsonBody (depthLimit : Nat) (body : String) : Except String (List Member) :=
  match JsonRead.value (4 * body.length + 16) depthLimit 0 "" body.toList with
  | .error e => .error s!"JSON parsing error: {e}"
  | .ok (leaves, rest) =>
    if (JsonRead.ws rest).isEmpty then .ok (leaves.map fun (k, v) => Member.mk (latin k) (text v))
    else .error "JSON parsing error: trailing data"

/-- Phase 2 additions when the body is read (`09#urlencoded`, `05#request_body`, ADR-0022):
`access` and `processor` come from the settings as overridden by phase 1 `ctl`s. -/
def phase2Store (st : Settings) (r : Request) (access : Bool) (processor : Option String) (force : Bool) (store : Store) : Store :=
  match r.body with
  | none => store
  | some body =>
    if !access then store else
    let ct := headerValue r.headers "Content-Type"
    let proc := selectProcessor processor ct
    let get := store.get "ARGS_GET"
    -- multipart (`09#multipart`): fields become arguments, files become FILES*
    let (parts, bad) := if proc != "MULTIPART" then ([], false) else
      match ct.bind (headerParam · "boundary") with | some b => parseMultipart b body | none => ([], true)
    let fileParts := parts.filter (·.filename.isSome)
    -- JSON (`09#json`): leaves become arguments; a malformed or too deep document is a body error
    let (jsonMembers, bodyError) : List Member × Option String := if proc != "JSON" then ([], none) else
      match parseJsonBody st.jsonDepthLimit body with | .ok ms => (ms, none) | .error e => ([], some e)
    let post := if proc == "URLENCODED" then parseArgs st.argSep none body
                else if proc == "JSON" then jsonMembers
                else (parts.filter (·.filename.isNone)).map fun p => Member.mk (latin p.name) p.content
    let all := limitArgs st.argsLimit (get ++ post)
    let post := all.drop get.length
    let reqBody := if proc == "URLENCODED" || force then scalar (text body) else []
    let files := fileParts.filterMap fun p => p.filename.map fun f => Member.mk (latin p.name) (text f)
    let store := store |>.set "ARGS_POST" post |>.set "ARGS_POST_NAMES" (namesOf post)
      |>.set "ARGS" all |>.set "ARGS_NAMES" (namesOf all)
      |>.set "ARGS_COMBINED_SIZE" (natText (combinedSize all))
      |>.set "REQUEST_BODY" reqBody |>.set "REQUEST_BODY_LENGTH" (natText (text body).size)
      |>.set "REQBODY_PROCESSOR" (scalar (text proc))
      |>.set "REQBODY_ERROR" (natText (if bodyError.isSome then 1 else 0))
      |>.set "REQBODY_ERROR_MSG" (scalar (text (bodyError.getD "")))
    if proc != "MULTIPART" then store else
    store |>.set "FILES" files |>.set "FILES_NAMES" (namesOf files)
      |>.set "FILES_COMBINED_SIZE" (natText (fileParts.foldl (fun n p => n + p.content.size) 0))
      |>.set "MULTIPART_PART_HEADERS" (parts.map fun p => Member.mk (latin p.name) (text p.headers))
      |>.set "MULTIPART_STRICT_ERROR" (natText (if bad then 1 else 0))

/-- Phase 3 additions (`05#response_status`, `05#response_headers`). -/
def phase3Store (resp : Option Response) (store : Store) : Store :=
  match resp with
  | none => store
  | some rs =>
    let hs := rs.headers.map fun (k, v) => Member.mk (latin k) (text (trimBlanks v))
    store |>.set "RESPONSE_STATUS" (natText rs.status) |>.set "RESPONSE_HEADERS" hs

/-- Phase 4 additions (`05#response_body`, `04#secresponsebodyaccess`): the body when access
is on and the MIME type (parameters stripped) is listed. -/
def phase4Store (st : Settings) (resp : Option Response) (store : Store) : Store :=
  match resp with
  | none => store
  | some rs => if responseBuffered st rs then store.set "RESPONSE_BODY" (scalar (text rs.body)) else store

#guard (parseArgs '&' none "a=1&a=2&b=3").map (fun m => (m.key, ofBytes m.value)) == [("a", "1"), ("a", "2"), ("b", "3")]
#guard (parseArgs '&' none "a=1&b&c=x+y%20z&d=%zz").map (fun m => (m.key, ofBytes m.value)) == [("a", "1"), ("b", ""), ("c", "x y z"), ("d", "%zz")]
#guard (parseArgs ';' none "a=1;b=2").map (·.key) == ["a", "b"]
#guard (parseArgs '&' (some 2) "a=1&b=2&c=3").map (·.key) == ["a", "b"]
#guard ((phase1Store {} { uri := "/dir/file.php?x=1" }).get "REQUEST_FILENAME").map (ofBytes ·.value) == ["/dir/file.php"]
#guard ((phase1Store {} { uri := "/dir/file.php?x=1" }).get "REQUEST_BASENAME").map (ofBytes ·.value) == ["file.php"]
#guard ((phase1Store {} { uri := "/dir/file.php?x=1" }).get "QUERY_STRING").map (ofBytes ·.value) == ["x=1"]
#guard ((phase1Store {} { uri := "/" }).get "DURATION").map (ofBytes ·.value) == ["0"]
#guard ((phase1Store {} { uri := "/", headers := [("Cookie", "a=1; b=2; a=3")] }).get "REQUEST_COOKIES").map (fun m => (m.key, ofBytes m.value)) == [("a", "1"), ("b", "2"), ("a", "3")]
#guard ((phase1Store {} { uri := "/", headers := [("X-Test", " Hello ")] }).get "REQUEST_HEADERS_NAMES").map (ofBytes ·.value) == ["X-Test"]
#guard (let s := phase1Store { argsLimit := some 2 } { uri := "/?a=1&b=2" }
        let s := phase2Store { argsLimit := some 2, requestBodyAccess := true } { method := "POST", uri := "/?a=1&b=2", headers := [("Content-Type", "application/x-www-form-urlencoded")], body := some "p=1" } true none false s
        (s.get "ARGS").length) == 2
#guard (let s := phase2Store { requestBodyAccess := true } { uri := "/", headers := [("Content-Type", "application/x-www-form-urlencoded; charset=utf-8")], body := some "p=1&q=2" } true none false (phase1Store {} { uri := "/" })
        ((s.get "REQBODY_PROCESSOR").map (ofBytes ·.value), (s.get "ARGS_POST").length, (s.get "REQUEST_BODY").map (ofBytes ·.value), (s.get "REQUEST_BODY_LENGTH").map (ofBytes ·.value))) == (["URLENCODED"], 2, ["p=1&q=2"], ["7"])
#guard (let s := phase2Store {} { uri := "/", headers := [("Content-Type", "text/plain")], body := some "a=1" } true none true (phase1Store {} { uri := "/" })
        ((s.get "REQUEST_BODY").map (ofBytes ·.value), (s.get "ARGS_POST").length)) == (["a=1"], 0)
#guard (let s := phase2Store {} { uri := "/", headers := [("Content-Type", "text/plain")], body := some "a=1" } true none false (phase1Store {} { uri := "/" })
        (s.get "REQUEST_BODY").length) == 0
#guard ((phase4Store { responseBodyAccess := true, mimeTypes := ["text/plain"] } (some { headers := [("Content-Type", "text/plain; charset=utf-8")], body := "leak" }) []).get "RESPONSE_BODY").map (ofBytes ·.value) == ["leak"]
#guard ((phase4Store { responseBodyAccess := true, mimeTypes := ["text/plain"] } (some { headers := [("Content-Type", "application/json")], body := "leak" }) []).get "RESPONSE_BODY").length == 0

def mpBody : String := "--XX\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\nhello\r\n--XX\r\nContent-Disposition: form-data; name=\"f\"; filename=\"a.txt\"\r\nContent-Type: text/plain\r\n\r\nabc\r\n--XX--\r\n"
#guard (parseArgs '&' none "a=1&&b=2").map (·.key) == ["a", "b"]
#guard ((parseMultipart "XX" mpBody).1.map fun p => (p.name, p.filename, ofBytes p.content)) == [("t", none, "hello"), ("f", some "a.txt", "abc")]
#guard (parseMultipart "XX" mpBody).2 == false
#guard (parseMultipart "XX" "--XX\nContent-Disposition: form-data; name=\"t\"\n\nhello\n--XX--\n").2 == true
#guard (parseMultipart "XX" "--XX\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\nhello\r\n").2 == true
#guard (parseMultipart "XX" "junk\r\n--XX\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\nhello\r\n--XX--\r\n").2 == true
#guard headerParam "multipart/form-data; boundary=\"XX\"" "boundary" == some "XX"
#guard headerParam "multipart/form-data; boundary=XX" "boundary" == some "XX"
#guard (let s := phase2Store { requestBodyAccess := true } { method := "POST", uri := "/", headers := [("Content-Type", "multipart/form-data; boundary=XX")], body := some mpBody } true none false (phase1Store {} { uri := "/" })
        ((s.get "ARGS_POST").map (fun m => (m.key, ofBytes m.value)), (s.get "FILES").map (fun m => (m.key, ofBytes m.value)), (s.get "FILES_NAMES").map (ofBytes ·.value),
         (s.get "FILES_COMBINED_SIZE").map (ofBytes ·.value), (s.get "MULTIPART_STRICT_ERROR").map (ofBytes ·.value), (s.get "REQBODY_PROCESSOR").map (ofBytes ·.value), (s.get "REQUEST_BODY").length))
  == ([("t", "hello")], [("f", "a.txt")], ["f"], ["3"], ["0"], ["MULTIPART"], 0)
#guard ((phase2Store { requestBodyAccess := true } { method := "POST", uri := "/", headers := [("Content-Type", "multipart/form-data; boundary=XX")], body := some mpBody } true none false (phase1Store {} { uri := "/" })).get "MULTIPART_PART_HEADERS").map (fun m => (m.key, (ofBytes m.value).startsWith "Content-Disposition")) == [("t", true), ("f", true)]

-- review fixes: a bare LF inside part content is not a strict error (v2 `msc_multipart.c` flags only boundary and header lines)
#guard (let (ps, bad) := parseMultipart "XX" "--XX\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\na\nb\r\n--XX--\r\n"
        (ps.map fun p => (p.name, p.headers, ofBytes p.content), bad)) == ([("t", "Content-Disposition: form-data; name=\"t\"", "a\nb")], false)
-- LF-delimited bodies still yield their parts
#guard ((parseMultipart "XX" "--XX\nContent-Disposition: form-data; name=\"t\"\n\nhello\n--XX--\n").1.map fun p => (p.name, ofBytes p.content)) == [("t", "hello")]
-- a boundary line with trailing data, or data after the closing delimiter, is a strict error
#guard (parseMultipart "XX" "--XX \r\nContent-Disposition: form-data; name=\"t\"\r\n\r\nattack\r\n--XX--\r\n").2 == true
#guard (parseMultipart "XX" "--XX\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\nab\r\n--XXY\r\ncd\r\n--XX--\r\n").2 == true
#guard (parseMultipart "XX" "--XX\r\nContent-Disposition: form-data; name=\"t\"\r\n\r\nhello\r\n--XX--\r\nTRAILING").2 == true
-- quoted parameter values may hold `;`
#guard headerParam "form-data; name=\"f\"; filename=\"shell;.php\"" "filename" == some "shell;.php"
#guard headerParam "form-data; name=\"a;b\"" "name" == some "a;b"

-- body limits (`04#secrequestbodylimitaction`, `04#secresponsebodylimitaction`)
#guard applyLimit (some 10) .reject true 413 "p=1&filler=0123456789" == ("p=1&filler=0123456789", false, some 413)
#guard applyLimit (some 10) .processPartial true 413 "p=1&filler=0123456789" == ("p=1&filler", true, none)
#guard applyLimit (some 10) .reject false 413 "p=1&filler=0123456789" == ("p=1&filler=0123456789", true, none)   -- DetectionOnly: flag set, whole body
#guard applyLimit (some 10) .reject true 413 "0123456789" == ("0123456789", false, none)
#guard applyLimit (some 5) .processPartial true 500 "0123456789" == ("01234", true, none)
#guard applyLimit none .reject true 413 "0123456789" == ("0123456789", false, none)

-- JSON (`09#json`): v2 key-path names, depth counted per container
#guard (let s := phase2Store { requestBodyAccess := true } { method := "POST", uri := "/", headers := [("Content-Type", "application/json")], body := some "{\"a\":" } true (some "JSON") false (phase1Store {} { uri := "/" })
        ((s.get "REQBODY_ERROR").map (ofBytes ·.value), (s.get "REQBODY_ERROR_MSG").any (·.value.size > 0), (s.get "ARGS_POST").length, (s.get "REQBODY_PROCESSOR").map (ofBytes ·.value))) == (["1"], true, 0, ["JSON"])
#guard (let s := phase2Store { requestBodyAccess := true, jsonDepthLimit := 2 } { method := "POST", uri := "/", headers := [], body := some "[1,[2,[3]]]" } true (some "JSON") false (phase1Store {} { uri := "/" })
        ((s.get "REQBODY_ERROR").map (ofBytes ·.value), (s.get "ARGS_POST").length)) == (["1"], 0)
#guard (let s := phase2Store { requestBodyAccess := true, jsonDepthLimit := 2 } { method := "POST", uri := "/", headers := [], body := some "[1,[2]]" } true (some "JSON") false (phase1Store {} { uri := "/" })
        ((s.get "REQBODY_ERROR").map (ofBytes ·.value), (s.get "ARGS_POST").map (fun m => (m.key, ofBytes m.value)))) == (["0"], [("array", "1"), ("array", "2")])
#guard (let s := phase2Store { requestBodyAccess := true } { uri := "/", headers := [("Content-Type", "application/x-www-form-urlencoded")], body := some "p=1" } true none false (phase1Store {} { uri := "/" })
        ((s.get "REQBODY_ERROR").map (ofBytes ·.value), (s.get "REQBODY_ERROR_MSG").map (ofBytes ·.value))) == (["0"], [""])

-- JSON leaves keep the number text as written and come in document order (`09#json`: "the leaf's text")
#guard (parseJsonBody 10 "[1.0, 1e2, 1.50, -0, 1E-2]").toOption.map (·.map fun m => ofBytes m.value) == some ["1.0", "1e2", "1.50", "-0", "1E-2"]
#guard (parseJsonBody 10 "{\"b\":1,\"a\":\"x\\u00e9\\n\"}").toOption.map (·.map fun m => (m.key, ofBytes m.value)) == some [("b", "1"), ("a", latin "xé\n")]
#guard (parseJsonBody 10 "{\"a\":1,} ").toOption.isNone
#guard (parseJsonBody 10 "{\"a\":1} x").toOption.isNone
#guard (parseJsonBody 10 " {\"a\" : [ true , null , \"s\" ] } ").toOption.map (·.map fun m => (m.key, ofBytes m.value)) == some [("a", "true"), ("a", ""), ("a", "s")]

end SecLang
