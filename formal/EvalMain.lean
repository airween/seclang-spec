import Lean.Data.Json
import SecLang

/-! Runs every engine profile the abstract transaction can carry through the processing model
and checks `triggered_rules`, `non_triggered_rules`, `interruption` and `no_interruption`.
Profiles needing features outside the model are reported as unsupported with the reason.
Exit 1 on any mismatch. -/
open Lean SecLang

structure Stage where
  title : String
  input : Request
  response : Option Response
  output : Json

structure Profile where
  path : String
  rules : String
  files : List (String × String)
  expectError : Bool
  stages : List Stage

def strD (j : Json) (k d : String) : String := ((j.getObjVal? k).bind Json.getStr?).toOption.getD d
def kvs (j : Json) (k : String) : List (String × String) :=
  match j.getObjVal? k with
  | .ok (.obj m) => m.toList.filterMap fun (n, v) => (v.getStr?).toOption.map (n, ·)
  | _ => []

def stageOf (title : String) (j : Json) : Except String Stage := do
  let st ← j.getObjVal? "stage"
  let inp := (st.getObjVal? "input").toOption.getD (Json.mkObj [])
  let req : Request := { method := strD inp "method" "GET", uri := strD inp "uri" "/", version := strD inp "version" "HTTP/1.1",
                         headers := kvs inp "headers", body := ((inp.getObjVal? "data").bind Json.getStr?).toOption,
                         remoteAddr := strD inp "remote_addr" "127.0.0.1" }
  let resp : Option Response := match st.getObjVal? "response" with
    | .ok r => some { status := ((r.getObjVal? "status").bind Json.getNat?).toOption.getD 200, headers := kvs r "headers", body := strD r "data" "" }
    | .error _ => none
  return ⟨title, req, resp, ← st.getObjVal? "output"⟩

def Profile.ofJson (j : Json) : Except String Profile := do
  let tests ← (j.getObjVal? "tests") >>= Json.getArr?
  let stages ← tests.toList.flatMapM fun t => do
    let title := strD t "test_title" ""
    let ss ← (t.getObjVal? "stages") >>= Json.getArr?
    ss.toList.mapM (stageOf title)
  return { path := ← j.getObjVal? "path" >>= Json.getStr?, rules := ← j.getObjVal? "rules" >>= Json.getStr?,
           files := kvs j "files", expectError := ← j.getObjVal? "expect_error" >>= Json.getBool?, stages }

def limitActionOf (v : String) : LimitAction :=
  if v.toLower == "processpartial" then .processPartial else .reject

/-- `SecRuleEngine` and the store settings from the configuration. -/
def settingsOf (cfg : Config) : Settings × Mode :=
  cfg.directives.foldl (fun (s, m) d => match d with
    | .setting _ "SecRuleEngine" [v] => (s, modeOf v)
    | .setting _ "SecArgumentSeparator" [v] => ({ s with argSep := v.toList.headD '&' }, m)
    | .setting _ "SecArgumentsLimit" [v] => ({ s with argsLimit := natOf? v }, m)
    | .setting _ "SecRequestBodyAccess" [v] => ({ s with requestBodyAccess := v.toLower == "on" }, m)
    | .setting _ "SecResponseBodyAccess" [v] => ({ s with responseBodyAccess := v.toLower == "on" }, m)
    | .setting _ "SecResponseBodyMimeType" vs => ({ s with mimeTypes := s.mimeTypes ++ vs }, m)
    | .setting _ "SecResponseBodyMimeTypesClear" _ => ({ s with mimeTypes := [] }, m)
    | .setting _ "SecRequestBodyLimit" [v] => ({ s with requestBodyLimit := natOf? v }, m)
    | .setting _ "SecResponseBodyLimit" [v] => ({ s with responseBodyLimit := natOf? v }, m)
    | .setting _ "SecRequestBodyLimitAction" [v] => ({ s with requestBodyLimitAction := limitActionOf v }, m)
    | .setting _ "SecResponseBodyLimitAction" [v] => ({ s with responseBodyLimitAction := limitActionOf v }, m)
    | .setting _ "SecRequestBodyJsonDepthLimit" [v] => ({ s with jsonDepthLimit := (natOf? v).getD s.jsonDepthLimit }, m)
    | _ => (s, m)) ({}, .off)

def unsupportedVariables : List String :=
  ["XML"]

/-- The first feature outside the model that a profile needs, if any. -/
def unsupportedReason (cfg : Config) (stages : List Stage) : Option String :=
  let rules := cfg.directives.filterMap fun | .rule r => some r | _ => none
  let ops := rules.filterMap fun r => r.operator.map (·.name)
  let targets := cfg.directives.flatMap fun
    | .updateTargetById _ _ ts => ts | .updateTargetByTag _ _ ts => ts | .updateTargetByMsg _ _ ts => ts | _ => []
  let allVars := rules.flatMap (·.variables) ++ targets
  let vars := allVars.map (·.collection)
  let acts := rules.flatMap (·.actions)
  let regexes := (rules.filterMap fun r => r.operator.bind fun op => if op.name == "rx" then some op.param else none) ++
    (allVars.filterMap fun v => match v.selector with | some (.regex re) => some re | _ => none)
  if let some op := ops.find? (fun n => !implemented.contains n) then some s!"operator @{op}"
  else if let some re := regexes.find? (fun re => match Regex.compile re with | .error _ => true | .ok _ => false) then some s!"regex outside the Core subset: {re}"
  else if let some v := vars.find? unsupportedVariables.contains then some s!"variable {v}"
  else if let some a := acts.find? (fun a => ["setsid", "setuid", "setrsc"].contains a.name) then some s!"action {a.name}"
  else if acts.any (fun a => a.name == "ctl" && (a.value.getD "").toLower.startsWith "requestbodyprocessor=xml") then some "body processor XML"
  else if stages.any (fun s => ["log_contains", "no_log_contains", "audit_log_contains", "no_audit_log_contains"].any
      fun k => (s.output.getObjVal? k).toOption.isSome) then some "log assertions"
  else if stages.any (fun s => s.input.body.isSome && (headerValue s.input.headers "Content-Type").any fun ct =>
            ct.toLower.endsWith "xml") then some "body processor XML"
  else none

def natList (j : Json) (k : String) : List Nat :=
  match (j.getObjVal? k).bind Json.getArr? with
  | .ok a => a.toList.filterMap fun x => (x.getNat?).toOption
  | .error _ => []

/-- Mismatches of one stage, in the adapters' wording. -/
def checkStage (o : Oracle) (items : List Item) (settings : Settings) (mode : Mode) (st : Stage) : List String :=
  let flag (b : Bool) : List Member := natText (if b then 1 else 0)
  let interrupt (tx : Tx) (status : Option Nat) : Option Interruption :=
    tx.interruption <|> status.map fun s => ⟨0, "deny", s⟩
  -- the phase-boundary hook: store population (`05`, `09`) and body limits (`04`)
  let prepare : Nat → Tx → Tx := fun p tx => match p with
    | 1 => { tx with store := phase1Store settings st.input }
    | 2 =>
      let access := tx.bodyAccess.getD settings.requestBodyAccess
      let (body, err, status) := match st.input.body with
        | some b => if access then applyLimit settings.requestBodyLimit settings.requestBodyLimitAction (tx.nextMode == .on) 413 b else (b, false, none)
        | none => ("", false, none)
      let req := { st.input with body := st.input.body.map fun _ => body }
      { tx with store := (phase2Store settings req access tx.bodyProcessor tx.forceBody tx.store).set "INBOUND_DATA_ERROR" (flag err),
                interruption := interrupt tx status }
    | 3 => { tx with store := phase3Store st.response tx.store }
    | 4 =>
      let (resp, err, status) := match st.response with
        | some rs => if responseBuffered settings rs then
            let (b, e, s) := applyLimit settings.responseBodyLimit settings.responseBodyLimitAction (tx.nextMode == .on) 500 rs.body
            (some { rs with body := b }, e, s)
          else (some rs, false, none)
        | none => (none, false, none)
      { tx with store := (phase4Store settings resp tx.store).set "OUTBOUND_DATA_ERROR" (flag err),
                interruption := interrupt tx status }
    | _ => tx
  let tx := runTransaction o items prepare { mode, nextMode := mode }
  let out := st.output
  let want := natList out "triggered_rules"
  let wantNot := natList out "non_triggered_rules"
  let m1 := (want.filter fun id => !tx.triggered.contains id).map fun id => s!"rule {id} expected triggered"
  let m2 := (wantNot.filter tx.triggered.contains).map fun id => s!"rule {id} expected not triggered"
  let m3 := match out.getObjVal? "interruption" with
    | .ok i =>
      let rid := ((i.getObjVal? "rule_id").bind Json.getNat?).toOption
      let act := ((i.getObjVal? "action").bind Json.getStr?).toOption
      let status := ((i.getObjVal? "status").bind Json.getNat?).toOption
      match tx.interruption with
      | none => [s!"expected interruption by rule {rid.getD 0}, got none"]
      | some got =>
        (if rid.any (· != got.ruleId) then [s!"interruption rule_id {got.ruleId}, expected {rid.getD 0}"] else []) ++
        (if act.any (· != got.action) then [s!"interruption action {got.action}, expected {act.getD ""}"] else []) ++
        (if status.any (· != got.status) then [s!"interruption status {got.status}, expected {status.getD 0}"] else [])
    | .error _ => []
  let m4 := match out.getObjVal? "no_interruption" with
    | .ok (.bool true) => match tx.interruption with | some i => [s!"unexpected interruption by rule {i.ruleId}"] | none => []
    | _ => []
  m1 ++ m2 ++ m3 ++ m4

def main (args : List String) : IO UInt32 := do
  let some file := args.head? | IO.eprintln "usage: seclang-eval engine-rules.json"; return 2
  let txt ← IO.FS.readFile file
  let profiles ← IO.ofExcept (Json.parse txt >>= Json.getArr? >>= (·.mapM Profile.ofJson))
  let mut stages := 0
  let mut mismatches := 0
  let mut unsupported := 0
  for p in profiles do
    let o : Oracle := { rxAt := Regex.searchAt, readFile := fun path => (resolveFile (p.files.map (·.1)) path).bind fun n => List.lookup n p.files }
    if p.expectError then
      IO.println s!"{p.path}: skipped (expect_error)"
      continue
    match parseConfig p.files p.rules with
    | .error e =>
      IO.println s!"{p.path}: cannot load: line {e.line}: {e.msg}  <-- MISMATCH"
      mismatches := mismatches + 1
    | .ok cfg =>
      match unsupportedReason cfg p.stages with
      | some why =>
        IO.println s!"{p.path}: unsupported ({why})"
        unsupported := unsupported + 1
      | none =>
        let (settings, mode) := settingsOf cfg
        let items := effectiveItems cfg
        for st in p.stages do
          stages := stages + 1
          let ms := checkStage o items settings mode st
          if ms.isEmpty then IO.println s!"{p.path} [{st.title}]: ok"
          else
            mismatches := mismatches + 1
            IO.println s!"{p.path} [{st.title}]: MISMATCH"
            for m in ms do IO.println s!"  {m}"
  IO.println s!"{stages} stages, {mismatches} mismatches, {unsupported} unsupported profiles"
  return if mismatches == 0 then 0 else 1
