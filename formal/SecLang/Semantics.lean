import SecLang.Syntax
import SecLang.Digest
import SecLang.Request
import SecLang.Operators
/-! The processing model (`spec/03-processing-model.md`): effective rules, one transaction
through five phases, parametric in a regular-expression oracle and in how the store is
populated per phase. -/
namespace SecLang

inductive Mode | on | off | detectionOnly
  deriving Repr, BEq, DecidableEq

def Mode.isOff : Mode → Bool | .off => true | _ => false

def modeOf (s : String) : Mode :=
  match s.toLower with | "off" => .off | "detectiononly" => .detectionOnly | _ => .on

structure Interruption where
  ruleId : Nat
  action : String
  status : Nat
  deriving Repr, BEq

inductive AllowScope | phase | request | all
  deriving Repr, BEq, DecidableEq

/-- A chain starter with its members and its effective disruptive action, status and
inherited cumulative actions (`03#chains`, `03#default-actions`). -/
structure Chain where
  id : Nat
  phase : Nat
  starter : Rule
  members : List Rule := []
  dflt : List Action              -- the SecDefaultAction list of its phase at definition time
  disruptive : Option String
  status : Option Nat
  extra : List Action
  deriving Repr

inductive Item
  | chain (c : Chain)
  | marker (label : String)
  deriving Repr

def actionValue (as : List Action) (n : String) : Option String := (as.find? (·.name == n)).bind (·.value)
def isDisruptiveName (n : String) : Bool := (findAction n).any (·.2.2 == .disruptive)
def ownDisruptive (as : List Action) : Option String := (as.find? fun a => isDisruptiveName a.name).map (·.name)
def cumulative (as : List Action) : List Action := as.filter fun a => a.name == "setvar" || a.name == "ctl" || a.name == "tag"

/-- `03#phases`, ADR-0017: the rule's own `phase` or 2; never taken from `SecDefaultAction`. -/
def chainPhase (r : Rule) : Nat := ((actionValue r.actions "phase").bind phaseNumber).getD 2

/-- The chain for a starter, with the default actions of its phase merged in: the rule's own
actions win; `block` takes the inherited disruptive action; cumulative actions are appended. -/
def mkChainD (dflt : List Action) (r : Rule) : Chain :=
  let phase := chainPhase r
  let inherited := match ownDisruptive dflt with | some "block" => none | d => d
  let disruptive := match ownDisruptive r.actions with
    | some "block" => inherited
    | some d => some d
    | none => inherited
  let status := match (actionValue r.actions "status").bind natOf? with
    | some s => some s | none => (actionValue dflt "status").bind natOf?
  { id := ((actionValue r.actions "id").bind natOf?).getD 0, phase, starter := r, dflt, disruptive, status, extra := cumulative dflt }

def mkChain (defaults : List (Nat × List Action)) (r : Rule) : Chain :=
  mkChainD ((defaults.lookup (chainPhase r)).getD []) r

/-- Merge an action list into a rule's own (`03#rule-exceptions`, rule-over-default
precedence): `t:`, `tag`, `setvar` and `ctl` are appended, a disruptive action replaces the
existing one, any other action replaces the one of the same name. -/
def mergeActions (own acts : List Action) : List Action :=
  acts.foldl (fun cur a =>
    if a.name == "t" || a.name == "tag" || a.name == "setvar" || a.name == "ctl" then cur ++ [a]
    else if isDisruptiveName a.name then (cur.filter fun b => !isDisruptiveName b.name) ++ [a]
    else (cur.filter (·.name != a.name)) ++ [a]) own

/-- `SecRuleUpdateActionById`: the chain rebuilt from the merged starter actions. -/
def updateActions (c : Chain) (acts : List Action) : Chain :=
  { mkChainD c.dflt { c.starter with actions := mergeActions c.starter.actions acts } with members := c.members }

def inRanges (ranges : List (Nat × Nat)) (id : Nat) : Bool := ranges.any fun (a, z) => a ≤ id && id ≤ z
def tagsOf (c : Chain) : List String := (c.starter.actions.filter (·.name == "tag")).filterMap (·.value)
def msgOf (c : Chain) : String := (actionValue c.starter.actions "msg").getD ""
/-- A regex selector against a member name: case-insensitive, like key selectors (ADR-0008). -/
def rxName (o : Oracle) (re s : String) : Bool := (o.rx ("(?i)" ++ re) (text s)).isSome
def addTargets (c : Chain) (ts : List Variable) : Chain :=
  { c with starter := { c.starter with variables := c.starter.variables ++ ts } }

structure Build where
  items : List Item := []          -- reversed
  cur : Option Chain := none
  defaults : List (Nat × List Action) := []

def Build.flush (b : Build) : Build :=
  match b.cur with | some c => { b with items := .chain c :: b.items, cur := none } | none => b
def Build.mapChains (b : Build) (f : Chain → Chain) : Build :=
  let b := b.flush
  { b with items := b.items.map fun | .chain c => .chain (f c) | i => i }
def Build.filterChains (b : Build) (p : Chain → Bool) : Build :=
  let b := b.flush
  { b with items := b.items.filter fun | .chain c => p c | _ => true }

/-- One directive into the build (`03#rule-exceptions`: each applies to the rules already
defined). -/
def buildStep (b : Build) : Directive → Build
  | .rule r =>
    if r.chainMember then
      match b.cur with
      | some c => { b with cur := some { c with members := c.members ++ [r] } }
      | none => b
    else
      let b := b.flush
      { b with cur := some (mkChain b.defaults r) }
  | .defaultAction _ phase acts => let b := b.flush; { b with defaults := (phase, acts) :: b.defaults }
  | .marker _ l => let b := b.flush; { b with items := .marker l :: b.items }
  | .removeById _ rs => b.filterChains fun c => !inRanges rs c.id
  -- tag and msg exceptions compare exactly (ADR-0029)
  | .removeByTag _ tag => b.filterChains fun c => !(tagsOf c).contains tag
  | .removeByMsg _ msg => b.filterChains fun c => msgOf c != msg
  | .updateActionById _ rs acts => b.mapChains fun c => if inRanges rs c.id then updateActions c acts else c
  | .updateTargetById _ rs ts => b.mapChains fun c => if inRanges rs c.id then addTargets c ts else c
  | .updateTargetByTag _ tag ts => b.mapChains fun c => if (tagsOf c).contains tag then addTargets c ts else c
  | .updateTargetByMsg _ msg ts => b.mapChains fun c => if msgOf c == msg then addTargets c ts else c
  | .setting .. => b

/-- Effective chains and markers in configuration order. -/
def effectiveItems (cfg : Config) : List Item :=
  (cfg.directives.foldl buildStep {}).flush.items.reverse

/-- Transaction state. -/
structure Tx where
  store : Store := []
  tx : List Member := []
  mode : Mode := .on
  nextMode : Mode := .on
  removedIds : List Nat := []
  removedTags : List String := []
  removedTargets : List (Nat × Variable) := []
  removedTagTargets : List (String × Variable) := []
  bodyAccess : Option Bool := none
  bodyProcessor : Option String := none
  forceBody : Bool := false
  interruption : Option Interruption := none
  allow : Option AllowScope := none
  ended : Bool := false
  triggered : List Nat := []
  evaluated : List Nat := []
  matchedVar : ByteArray := .empty
  matchedVarName : String := ""
  matchedVars : List Member := []
  /-- Persistent collections initialised by `initcol` in this transaction (`IP`, `GLOBAL`, …),
  by upper-case name. Persistence across transactions and expiry are not modelled. -/
  colls : List (String × List Member) := []

def keyEq (a b : String) : Bool := a.toLower == b.toLower

/-- Members of a collection, `TX` and the `MATCHED_*` variables included. -/
def collection (tx : Tx) (name : String) : List Member :=
  match name with
  | "TX" => tx.tx
  | "MATCHED_VAR" => scalar tx.matchedVar
  | "MATCHED_VAR_NAME" => scalar (bytesOf tx.matchedVarName)
  | "MATCHED_VARS" => tx.matchedVars
  | _ =>
    let ms := match tx.colls.lookup name with | some ms => ms | none => tx.store.get name
    -- a scalar always has exactly one value (`05`): the empty string until it is set
    if ms.isEmpty then (match findVariable name with | some (_, .scalar) => scalar .empty | _ => ms) else ms

def fullName (coll : String) (m : Member) : String := if m.key.isEmpty then coll else s!"{coll}:{m.key}"

def selectMembers (o : Oracle) (tx : Tx) (v : Variable) : List Member :=
  let ms := collection tx v.collection
  match v.selector with
  | none => ms
  | some (.key k) => ms.filter fun m => keyEq m.key (latin k)
  | some (.regex re) => ms.filter fun m => rxName o re m.key
  | some (.xpath _) => []

/-- Does the exclusion `v` cover a selected value named `name` (`COLL` or `COLL:key`)? -/
def covers (o : Oracle) (v : Variable) (name : String) : Bool :=
  let (coll, key) := match name.splitOn ":" with
    | [c] => (c, "") | c :: rest => (c, ":".intercalate rest) | [] => ("", "")
  keyEq coll v.collection && match v.selector with
    | none => true
    | some (.key k) => keyEq key (latin k)
    | some (.regex re) => rxName o re key
    | some (.xpath _) => false

/-- The values a variable list selects (`02#variable-list`): union in order, `!` removes,
`&` counts; extra exclusions come from `ctl:ruleRemoveTarget*`. -/
def selectValues (o : Oracle) (tx : Tx) (vars : List Variable) (exclusions : List Variable) : List (String × ByteArray) :=
  let step (acc : List (String × ByteArray)) (v : Variable) : List (String × ByteArray) :=
    if v.negate then acc.filter fun (n, _) => !covers o v n
    else if v.count then acc ++ [(v.collection, text (toString (selectMembers o tx v).length))]
    else acc ++ (selectMembers o tx v).map fun m => (fullName v.collection m, m.value)
  (vars ++ exclusions.map fun (e : Variable) => { e with negate := true }).foldl step []

/-- The `t:` list of a rule; `t:none` resets (`07#none`). -/
def tfnList (as : List Action) : List String :=
  as.foldl (fun acc a => if a.name == "t" then (match a.value with | some "none" => [] | some t => acc ++ [t] | none => acc) else acc) []
def applyTfn (name : String) (v : ByteArray) : ByteArray := match byName.lookup name with | some f => f v | none => v

def macroValue (tx : Tx) (name : String) : ByteArray :=
  let (coll, key) := match name.splitOn "." with
    | [c] => (c, none) | c :: rest => (c, some (".".intercalate rest)) | [] => ("", none)
  let coll := ((findVariable coll).map (·.1)).getD coll.toUpper
  let ms := collection tx coll
  match key with
  | none => ((ms.head?).map (·.value)).getD .empty
  | some k => ((ms.find? fun m => keyEq m.key (latin k)).map (·.value)).getD .empty

/-- `%{NAME}` and `%{COLL.key}` expansion (`02#macro-expansion`); an unset variable is empty. -/
def expandMacros (tx : Tx) (s : String) : ByteArray := go s.toList .empty
where
  go : List Char → ByteArray → ByteArray
    | '%' :: '{' :: rest, acc => inMacro rest [] acc
    | c :: rest, acc => go rest (acc ++ (String.singleton c).toUTF8)
    | [], acc => acc
  /-- Inside `%{…}`: the name so far (reversed); an unterminated macro runs to the end. -/
  inMacro : List Char → List Char → ByteArray → ByteArray
    | '}' :: rest, name, acc => go rest (acc ++ macroValue tx (String.ofList name.reverse))
    | c :: rest, name, acc => inMacro rest (c :: name) acc
    | [], name, acc => acc ++ macroValue tx (String.ofList name.reverse)

def setCaptures (tx : Tx) (caps : Array (Option ByteArray)) : Tx :=
  let keep := tx.tx.filter fun m => !(m.key.length == 1 && m.key.toList.all Char.isDigit)
  let new := (List.range (min caps.size 10)).filterMap fun i => (caps[i]!).map fun v => Member.mk (toString i) v
  { tx with tx := new ++ keep }

/-- `setvar` (`08#setvar`) on `TX` or on a persistent collection this transaction initialised
with `initcol` (`05#persistent-collections`); a write to a collection that was not
initialised is ignored (v2 logs "collection does not exist"). -/
def applySetvar (tx : Tx) (v : String) : Tx :=
  let (del, v) := if v.startsWith "!" then (true, dropFirst v) else (false, v)
  let (target, value) := match v.splitOn "=" with
    | [t] => (t, none) | t :: rest => (t, some ("=".intercalate rest)) | [] => ("", none)
  let (coll, key) := match target.splitOn "." with
    | c :: rest => (c.toUpper, ".".intercalate rest) | [] => ("", "")
  match (if coll == "TX" then some tx.tx else tx.colls.lookup coll) with
  | none => tx
  | some members =>
    let key := latin key
    let others := members.filter fun m => !keyEq m.key key
    let current := ((members.find? fun m => keyEq m.key key).map (·.value)).getD .empty
    let newVal : ByteArray := match value with
      | none => text "1"
      | some s =>
        let e := expandMacros tx s
        let es := ofBytes e
        if es.startsWith "+" then text (toString (atoi current + atoi (text (dropFirst es))))
        else if es.startsWith "-" then text (toString (atoi current - atoi (text (dropFirst es))))
        else e
    let updated := if del then others else others ++ [⟨key, newVal⟩]
    if coll == "TX" then { tx with tx := updated }
    else { tx with colls := tx.colls.map fun (n, ms) => if n == coll then (n, updated) else (n, ms) }

/-- `initcol:NAME=KEY` (`08#initcol`): the collection exists for the rest of the transaction;
the key is expanded and discarded since nothing persists. -/
def applyInitcol (tx : Tx) (v : String) : Tx :=
  let name := ((v.splitOn "=").headD "").toUpper
  if name.isEmpty || (tx.colls.lookup name).isSome then tx else { tx with colls := tx.colls ++ [(name, [])] }

/-- `ctl` (`03#ctl-timing`): rule edits are immediate; `ruleEngine` applies at once to the
interruption decision (after `Off` or `DetectionOnly` no later rule of the phase interrupts)
and to every later phase; after `Off` no further rule runs at all (ADR-0034, `runItems`). -/
def applyCtl (tx : Tx) (v : String) : Tx :=
  let (opt, val) := match v.splitOn "=" with | [o] => (o, "") | o :: rest => (o, "=".intercalate rest) | [] => ("", "")
  let ranges (r : String) : List (Nat × Nat) := (parseRanges 0 [r]).toOption.getD []
  let ids (r : String) : List Nat := (ranges r).flatMap fun (a, z) => (List.range (z + 1 - a)).map (· + a)
  let target (t : String) : Option Variable := ((parseVariables 0 t).toOption.bind List.head?)
  match opt with
  | "ruleEngine" =>
    let m := modeOf val
    { tx with nextMode := m, mode := m }
  | "ruleRemoveById" => { tx with removedIds := tx.removedIds ++ ids val }
  | "ruleRemoveByTag" => { tx with removedTags := tx.removedTags ++ [val] }
  | "ruleRemoveTargetById" => match val.splitOn ";" with
    | [r, t] => match target t with
      | some tv => { tx with removedTargets := tx.removedTargets ++ (ids r).map (·, tv) }
      | none => tx
    | _ => tx
  | "ruleRemoveTargetByTag" => match val.splitOn ";" with
    | [tag, t] => match target t with
      | some tv => { tx with removedTagTargets := tx.removedTagTargets ++ [(tag, tv)] }
      | none => tx
    | _ => tx
  | "requestBodyAccess" => { tx with bodyAccess := some (val.toLower == "on") }
  | "requestBodyProcessor" => { tx with bodyProcessor := some val, store := tx.store.set "REQBODY_PROCESSOR" (scalar (text val.toUpper)) }   -- set at once, body or not (05#reqbody_processor)
  | "forceRequestBodyVariable" => { tx with forceBody := val.toLower == "on" }
  | _ => tx

/-- The non-disruptive effects of a matching rule or inherited list. -/
def applyActions (tx : Tx) (as : List Action) : Tx :=
  as.foldl (fun tx a => match a.name, a.value with
    | "setvar", some v => applySetvar tx v
    | "initcol", some v => applyInitcol tx v
    | "ctl", some v => applyCtl tx v
    | _, _ => tx) tx   -- `expirevar` has no effect within one transaction

/-- Exclusions a chain inherits from `ctl:ruleRemoveTarget*` for this transaction; the tag
form compares exactly, as for the directive (`03#rule-exceptions`, ADR-0029). -/
def targetExclusions (tx : Tx) (c : Chain) : List Variable :=
  (tx.removedTargets.filter (·.1 == c.id)).map (·.2) ++
  (tx.removedTagTargets.filter fun (tag, _) => (tagsOf c).contains tag).map (·.2)

/-- One rule of a chain (`02#secrule-structure`, `02#operator`, `08#multimatch`,
`06#unconditionalmatch`): the rule matches when some value matches (negation per value, ADR-0030); the
operator fails for every value and at least one value was selected. -/
def runRule (o : Oracle) (c : Chain) (r : Rule) (tx : Tx) : Tx × Bool :=
  match r.operator with
  | none => (applyActions tx r.actions, true)
  | some op =>
    let values := selectValues o tx r.variables (targetExclusions tx c)
    let param := expandMacros tx op.param
    let tfns := tfnList r.actions
    let multi := hasAction r.actions "multiMatch"
    let results := values.map fun (name, v) =>
      let stages : List ByteArray := if multi then tfns.foldl (fun acc t => acc ++ [applyTfn t (acc.getLastD v)]) [v]
                    else [tfns.foldl (fun w t => applyTfn t w) v]
      let hits := stages.filterMap fun w => let (ok, caps) := evalOperator o op.name param w; if ok then some (w, caps) else none
      (name, hits.getLast?, stages.getLastD v)
    -- negation applies per value (ADR-0030): the rule matches when some value fails the operator
    let matched := if op.negate then results.any (·.2.1.isNone) else results.any (·.2.1.isSome)
    if !matched then (tx, false) else
    let hits := results.filterMap fun (n, h, _) => h.map fun (w, caps) => (n, w, caps)
    let (name, value, caps) := match hits.getLast? with
      | some h => h
      | none => match results.getLast? with | some (n, _, w) => (n, w, none) | none => ("", .empty, none)
    let tx := { tx with matchedVar := value, matchedVarName := name,
                        matchedVars := hits.map fun (n, w, _) => ⟨n, w⟩ }
    let tx := if hasAction r.actions "capture" then (match caps with | some cs => setCaptures tx cs | none => tx) else tx
    (applyActions tx r.actions, true)

/-- A chain: members in order, stopping at the first that does not match (`03#chains`). -/
def runChain (o : Oracle) (c : Chain) (tx : Tx) : Tx × Bool :=
  let tx := { tx with evaluated := tx.evaluated ++ [c.id] }
  (c.starter :: c.members).foldl (fun (tx, ok) r => if ok then runRule o c r tx else (tx, false)) (tx, true)

def removed (tx : Tx) (c : Chain) : Bool :=
  tx.removedIds.contains c.id || tx.removedTags.any (tagsOf c).contains

def allowScopeOf (c : Chain) : AllowScope :=
  match actionValue c.starter.actions "allow" with | some "phase" => .phase | some "request" => .request | _ => .all

def redirectStatus (s : Option Nat) : Nat :=
  match s with | some n => if n == 301 || n == 302 || n == 303 || n == 307 then n else 302 | none => 302

/-- After a whole chain matched (`03#disruptive-actions`, `08#allow`): record, run the
inherited cumulative actions, and in mode `On` outside phase 5 apply the disruptive action
(`03#phases`: in the logging phase disruptive actions have no effect). -/
def afterMatch (phase : Nat) (c : Chain) (tx : Tx) : Tx :=
  let tx := applyActions { tx with triggered := tx.triggered ++ [c.id] } c.extra
  if phase == 5 || tx.mode != .on then tx else
  match c.disruptive with
  | some "deny" => { tx with interruption := some ⟨c.id, "deny", c.status.getD 403⟩, ended := true }
  | some "drop" => { tx with interruption := some ⟨c.id, "drop", c.status.getD 403⟩, ended := true }
  | some "redirect" => { tx with interruption := some ⟨c.id, "redirect", redirectStatus c.status⟩, ended := true }
  | some "allow" => { tx with allow := some (allowScopeOf c), ended := true }
  | _ => tx

/-- Per-phase flow-control state (`03#flow-control`): local to the phase. -/
structure PhaseState where
  skip : Nat := 0
  skipAfter : Option String := none

def skipOf (c : Chain) : Nat := ((actionValue c.starter.actions "skip").bind natOf?).getD 0
def skipAfterOf (c : Chain) : Option String := actionValue c.starter.actions "skipAfter"
/-- The rules of one phase in order. A pending `skipAfter` passes everything until a marker
with that label (a rule id is never a label, ADR-0028); `skip` passes the next rules of the phase; chains of other
phases and removed chains are passed over; a match applies its actions and may end the
phase. -/
def runItems (o : Oracle) (phase : Nat) : List Item → PhaseState → Tx → Tx
  | [], _, tx => tx
  | item :: rest, ps, tx =>
    if tx.ended || tx.mode.isOff then tx else
    match item with
    | .marker l => runItems o phase rest (if ps.skipAfter == some l then { ps with skipAfter := none } else ps) tx
    | .chain c =>
      match ps.skipAfter with
      | some _ => runItems o phase rest ps tx
      | none =>
        if c.phase != phase || removed tx c then runItems o phase rest ps tx
        else if ps.skip > 0 then runItems o phase rest { ps with skip := ps.skip - 1 } tx
        else
          let (tx', matched) := runChain o c tx
          if matched then runItems o phase rest ⟨skipOf c, skipAfterOf c⟩ (afterMatch phase c tx')
          else runItems o phase rest ps tx'

def allowPermits (a : Option AllowScope) (p : Nat) : Bool :=
  match a with | none => true | some .phase => true | some .request => p > 2 | some .all => p == 5

/-- Whether phase `p` runs (`03#phases`, `03#disruptive-actions`, `08#allow`): never with the
engine off; phase 5 always otherwise; phases 1–4 unless interrupted or allowed past. -/
def phaseRuns (tx : Tx) (p : Nat) : Bool :=
  tx.mode != .off && (p == 5 || (tx.interruption.isNone && allowPermits tx.allow p))

/-- Phase boundary: the mode chosen by `ctl:ruleEngine` applies, `allow:phase` expires,
the `MATCHED_*` variables are cleared (their value across rules is unspecified). -/
def startPhase (tx : Tx) : Tx :=
  { tx with mode := tx.nextMode, ended := false,
            allow := if tx.allow == some .phase then none else tx.allow,
            matchedVar := .empty, matchedVarName := "", matchedVars := [] }

/-- The rules of one phase: cross the boundary, run the rules with fresh flow-control state. -/
def phaseBody (o : Oracle) (items : List Item) (p : Nat) (tx : Tx) : Tx :=
  let tx := startPhase tx
  if phaseRuns tx p then runItems o p items {} tx else tx

/-- One phase. `prepare` is the phase-boundary hook: it populates the store from the request
or response (`05`, `09`) and, at phases 2 and 4, applies the body limits (`04`), which may
set the interruption before any rule of the phase runs. -/
def step (o : Oracle) (items : List Item) (prepare : Nat → Tx → Tx) (p : Nat) (tx : Tx) : Tx :=
  phaseBody o items p (prepare p tx)

/-- A transaction: the five phases in order. -/
def runTransaction (o : Oracle) (items : List Item) (prepare : Nat → Tx → Tx) (tx : Tx) : Tx :=
  [1, 2, 3, 4, 5].foldl (fun tx p => step o items prepare p tx) tx

/-! ## Theorems for the Divergence ADRs -/

/-- ADR-0017: a rule without `phase` runs in phase 2. -/
theorem phase_default (r : Rule) (h : actionValue r.actions "phase" = none) : chainPhase r = 2 := by
  simp [chainPhase, h]

/-- ADR-0017: the phase never comes from the default actions in force. -/
theorem phase_not_inherited (d₁ d₂ : List (Nat × List Action)) (r : Rule) :
    (mkChain d₁ r).phase = (mkChain d₂ r).phase := rfl

/-- ADR-0016, by construction: every phase starts with no pending `skipAfter` and no `skip`
count (this restates `step`; the flow-control state is not part of `Tx`). -/
theorem skipAfter_ends_with_phase (o : Oracle) (items : List Item) (prepare : Nat → Tx → Tx) (p : Nat) (tx : Tx) :
    step o items prepare p tx =
      (let tx' := startPhase (prepare p tx)
       if phaseRuns tx' p then runItems o p items ⟨0, none⟩ tx' else tx') := rfl

/-- ADR-0016: a pending label that no later marker carries leaves the transaction untouched
for the rest of its phase (chains never carry a label, ADR-0028). -/
theorem skipAfter_missing (o : Oracle) (p k : Nat) (l : String) (items : List Item) (tx : Tx)
    (h : ∀ i ∈ items, (match i with | .marker m => m ≠ l | .chain _ => True)) :
    runItems o p items ⟨k, some l⟩ tx = tx := by
  induction items generalizing tx with
  | nil => rfl
  | cons i rest ih =>
    have hi := h i (List.mem_cons_self ..)
    have hr : ∀ j ∈ rest, (match j with | .marker m => m ≠ l | .chain _ => True) :=
      fun j hj => h j (List.mem_cons_of_mem _ hj)
    cases i with
    | marker m =>
      have hne : (some l == some m) = false := by
        rw [beq_eq_false_iff_ne]
        intro e
        exact hi (Option.some.inj e).symm
      simp only [runItems]
      split
      · rfl
      · simp [hne]
        exact ih tx hr
    | chain c =>
      simp only [runItems]
      split
      · rfl
      · exact ih tx hr

/-- ADR-0016, the consequence the ADR states: after a phase whose `skipAfter` label was never
found, any later phase runs exactly as if that `skipAfter` had not fired. -/
theorem later_phase_unaffected (o : Oracle) (p q k : Nat) (l : String) (items : List Item)
    (prepare : Nat → Tx → Tx) (tx : Tx)
    (h : ∀ i ∈ items, (match i with | .marker m => m ≠ l | .chain _ => True)) :
    step o items prepare q (runItems o p items ⟨k, some l⟩ tx) = step o items prepare q tx := by
  rw [skipAfter_missing o p k l items tx h]

/-- An interruption in an earlier phase: phases 2–4 evaluate nothing. -/
theorem interrupted_phase_quiet (o : Oracle) (items : List Item) (p : Nat) (tx : Tx)
    (hp : p ≠ 5) (hi : tx.interruption.isSome) :
    (phaseBody o items p tx).evaluated = tx.evaluated := by
  have hp' : (p == 5) = false := by simpa using hp
  have hn : tx.interruption ≠ none := by
    intro e
    rw [e] at hi
    simp at hi
  simp [phaseBody, startPhase, phaseRuns, hp', hn]

/-- A body limit with `Reject` (`04#secrequestbodylimitaction`): when the boundary hook sets
the interruption at a phase other than 5, no rule of that phase is evaluated. -/
theorem body_limit_reject_quiet (o : Oracle) (items : List Item) (prepare : Nat → Tx → Tx) (p : Nat) (tx : Tx)
    (hp : p ≠ 5) (hi : (prepare p tx).interruption.isSome) :
    (step o items prepare p tx).evaluated = (prepare p tx).evaluated :=
  interrupted_phase_quiet o items p (prepare p tx) hp hi

/-- ADR-0028: while a `skipAfter` label is pending, a chain is passed over whatever its id;
only a marker can end the skip. -/
theorem skipAfter_ignores_chain (o : Oracle) (p k : Nat) (l : String) (c : Chain) (rest : List Item)
    (tx : Tx) (h : tx.ended = false) :
    runItems o p (.chain c :: rest) ⟨k, some l⟩ tx = runItems o p rest ⟨k, some l⟩ tx := by
  cases hm : tx.mode with
  | off => cases rest <;> simp [runItems, hm, Mode.isOff]
  | on | detectionOnly => simp [runItems, h, hm, Mode.isOff]

/-- ADR-0029: a `ctl:ruleRemoveByTag` parameter removes a chain exactly when it equals one of
the chain's tags (no substring or regular-expression match). -/
theorem removed_by_tag_exact (tx : Tx) (c : Chain) (hid : c.id ∉ tx.removedIds) :
    removed tx c = tx.removedTags.any (tagsOf c).contains := by
  simp [removed, hid]

/-- ADR-0034: once the mode is `Off`, no further rule of the phase runs (and `phaseRuns` keeps
every later phase from starting). -/
theorem off_is_final (o : Oracle) (p : Nat) (items : List Item) (ps : PhaseState) (tx : Tx)
    (h : tx.mode = .off) : runItems o p items ps tx = tx := by
  cases items with
  | nil => rfl
  | cons i rest => simp [runItems, h, Mode.isOff]

/-- Phase 5 runs whenever the engine is not off at its boundary, interrupted or not. -/
theorem logging_phase_runs (tx : Tx) (h : tx.nextMode ≠ .off) : phaseRuns (startPhase tx) 5 = true := by
  simp only [phaseRuns, startPhase]
  cases hm : tx.nextMode with
  | off => exact absurd hm h
  | on => rfl
  | detectionOnly => rfl

def run (cfg : String) (store : Store) : Tx :=
  match parseConfig [] cfg with
  | .ok c => runTransaction testOracle (effectiveItems c) (fun _ tx => if tx.store.isEmpty then { tx with store } else tx) {}
  | .error _ => {}
def tri (tx : Tx) : List Nat := tx.triggered
def demoStore (args : List (String × String)) : Store :=
  [("ARGS_GET", args.map fun (k, v) => ⟨k, text v⟩), ("ARGS", args.map fun (k, v) => ⟨k, text v⟩), ("REQUEST_HEADERS", [⟨"X-P", text "1"⟩])]

#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 2\" \"id:2,phase:1,pass\"" (demoStore [("a", "1")])) == [1]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,skip:1\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:1,pass,skipAfter:END\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:1,pass\"\nSecMarker END\nSecRule ARGS_GET:a \"@streq 1\" \"id:5,phase:1,pass\"" (demoStore [("a", "1")])) == [1, 3, 5]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,skipAfter:3\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:1,pass\"" (demoStore [("a", "1")])) == [1]   -- a rule id is not a label (ADR-0028)
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,skipAfter:NOWHERE\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,pass\"" (demoStore [("a", "1")])) == [1, 3]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,chain\"\n  SecRule ARGS_GET:b \"@streq 2\" \"t:none\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass,chain\"\n  SecRule ARGS_GET:b \"@streq 3\"" (demoStore [("a", "1"), ("b", "2")])) == [1]
#guard tri (run "SecRule ARGS_GET:zz \"!@streq x\" \"id:1,phase:1,pass\"" (demoStore [("a", "1")])) == []
#guard tri (run "SecRule ARGS_GET:a \"!@streq x\" \"id:1,phase:1,pass\"" (demoStore [("a", "1")])) == [1]
#guard (run "SecDefaultAction \"phase:1,log,deny,status:418\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1\"" (demoStore [("a", "1")])).interruption == some ⟨1, "deny", 418⟩
#guard (run "SecDefaultAction \"phase:1,log,deny,status:418\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,status:403\"" (demoStore [("a", "1")])).interruption == some ⟨1, "deny", 403⟩
#guard (run "SecDefaultAction \"phase:1,log,deny,status:418\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass\"" (demoStore [("a", "1")])).interruption == none
#guard (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,block\"" (demoStore [("a", "1")])).interruption == none
#guard (run "SecDefaultAction \"phase:1,log,deny,status:403\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,block\"" (demoStore [("a", "1")])).interruption == some ⟨1, "deny", 403⟩
#guard (let tx := run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,deny,status:401\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,deny\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,deny\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:5,pass\"" (demoStore [("a", "1")])
        (tx.triggered, tx.interruption)) == ([1, 4], some ⟨1, "deny", 401⟩)
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,allow:request\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:3,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:5,phase:5,pass\"" (demoStore [("a", "1")])) == [1, 4, 5]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleEngine=Off\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,pass\"" (demoStore [("a", "1")])) == [1]
-- ADR-0034: a later ctl:ruleEngine=On cannot switch inspection back on
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleEngine=Off\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass,nolog,ctl:ruleEngine=On\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,deny\"" (demoStore [("a", "1")])) == [1]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleRemoveById=2\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"" (demoStore [("a", "1")])) == [1]
#guard tri (run "SecAction \"id:1,phase:1,pass,nolog,setvar:tx.a=5,setvar:tx.a=+3,setvar:tx.b=%{tx.a},setvar:tx.c=x,setvar:!tx.c,setvar:tx.d\"\nSecRule TX:a \"@eq 8\" \"id:2,phase:1,pass\"\nSecRule TX:b \"@streq 8\" \"id:3,phase:1,pass\"\nSecRule &TX:c \"@eq 0\" \"id:4,phase:1,pass\"\nSecRule TX:d \"@eq 1\" \"id:5,phase:1,pass\"" (demoStore [])) == [1, 2, 3, 4, 5]
#guard tri (run "SecRule ARGS_GET:a \"@rx ^(\\w+)-(\\w+)$\" \"id:1,phase:1,pass,capture,setvar:tx.first=%{TX.1}\"\nSecRule TX:first \"@streq foo\" \"id:2,phase:1,pass\"\nSecRule TX:0 \"@streq foo-bar\" \"id:3,phase:1,pass\"\nSecRule TX:2 \"@streq bar\" \"id:4,phase:1,pass\"" (demoStore [("a", "foo-bar")])) == [1, 2, 3, 4]
#guard tri (run "SecRule ARGS_GET:a \"@streq abc\" \"id:1,phase:1,pass,t:lowercase,t:hexEncode,multiMatch\"\nSecRule ARGS_GET:a \"@streq abc\" \"id:2,phase:1,pass,t:lowercase,t:hexEncode\"\nSecRule ARGS_GET:a \"@streq ABC\" \"id:3,phase:1,pass,t:lowercase,t:none\"" (demoStore [("a", "ABC")])) == [1, 3]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,tag:'drop-me'\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a|ARGS_GET:b \"@streq 1\" \"id:3,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:1,deny\"\nSecRuleRemoveByTag drop-me\nSecRuleRemoveById 2\nSecRuleUpdateTargetById 3 \"!ARGS_GET:a\"\nSecRuleUpdateActionById 4 \"pass\"" (demoStore [("a", "1")])) == [4]
-- regex selectors ignore case, like key selectors (ADR-0008)
#guard tri (run "SecAction \"id:1,phase:1,pass,nolog,setvar:tx.Score=5\"\nSecRule TX:/^SCORE$/ \"@eq 5\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:/^A$/ \"@streq x\" \"id:3,phase:1,pass\"" (demoStore [("a", "x")])) == [1, 2, 3]
#guard tri (run "SecRule &ARGS_GET \"@eq 2\" \"id:1,phase:1,pass\"\nSecRule ARGS_GET|!ARGS_GET:skip \"@streq x\" \"id:2,phase:1,pass\"" (demoStore [("skip", "x"), ("b", "2")])) == [1]
#guard tri (run "SecRule ARGS_GET:a \"@streq %{tx.expected}\" \"id:2,phase:1,pass\"\nSecAction \"id:1,phase:1,pass,nolog,setvar:tx.expected=secret\"\nSecRule ARGS_GET:a \"@streq %{TX.EXPECTED}\" \"id:3,phase:1,pass\"" (demoStore [("a", "secret")])) == [1, 3]
#guard tri (run "SecRule ARGS_GET:a \"@streq hello\" \"id:1,phase:1,pass,t:lowercase,chain\"\n  SecRule MATCHED_VAR \"@streq hello\" \"t:none\"\nSecRule ARGS_GET:a \"@streq hello\" \"id:2,phase:1,pass,t:lowercase,chain\"\n  SecRule MATCHED_VAR_NAME \"@streq ARGS_GET:a\" \"t:none\"\nSecRule ARGS_GET:b|ARGS_GET:c \"@rx ^v\" \"id:3,phase:1,pass,chain\"\n  SecRule &MATCHED_VARS \"@eq 2\" \"t:none\"" (demoStore [("a", "HeLLo"), ("b", "v1"), ("c", "v2")])) == [1, 2, 3]
#guard tri (run "SecRule REQUEST_HEADERS:X-P \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleRemoveTargetById=2;ARGS_GET:a\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:1,pass\"" (demoStore [("a", "1")])) == [1, 3]
#guard tri (run "SecRule ARGS_GET:q \"@pm forbidden other\" \"id:1,phase:1,pass\"\nSecRule &ARGS_GET \"@lt 3\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:a \"@eq 0\" \"id:3,phase:1,pass\"\nSecRule ARGS_GET:q \"@contains FORB\" \"id:4,phase:1,pass\"" (demoStore [("q", "this is FORBIDDEN"), ("a", "abc")])) == [1, 2, 3, 4]

#guard (let tx := run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleEngine=DetectionOnly\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,deny\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,deny\"" (demoStore [("a", "1")])
        (tx.triggered, tx.interruption)) == ([1, 2, 3], none)
-- review fixes: phase 5 has no disruptive effect; Off stops interruptions at once; skipAfter to an
-- id of another phase does not end the skip; ctl tag options are regexes; updates merge actions
#guard (let tx := run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,deny,status:401\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:5,deny,status:499\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:5,allow\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:5,pass\"" (demoStore [("a", "1")])
        (tx.triggered, tx.interruption)) == ([1, 2, 3, 4], some ⟨1, "deny", 401⟩)
#guard (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:5,deny\"" (demoStore [("a", "1")])).interruption == none
#guard (let tx := run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleEngine=Off\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,deny\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:2,pass\"" (demoStore [("a", "1")])
        (tx.triggered, tx.interruption)) == ([1], none)
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,skipAfter:5\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:5,phase:2,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:6,phase:1,pass\"" (demoStore [("a", "1")])) == [1, 5]
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,nolog,ctl:ruleRemoveByTag=attack\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass,tag:'attack-sqli'\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:1,pass\"" (demoStore [("a", "1")])) == [1, 2, 3]   -- `attack` is not the tag `attack-sqli` (ADR-0029)
#guard tri (run "SecRule ARGS_GET:a \"@streq abc\" \"id:1,phase:1,pass\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass\"\nSecRuleUpdateActionById 1 \"t:lowercase\"\nSecRuleUpdateActionById 2 \"tag:'gone'\"\nSecRuleRemoveByTag gone" (demoStore [("a", "ABC")])) == [1]

def runReq (cfg : String) (req : Request) : Tx :=
  match parseConfig [] cfg with
  | .ok c => runTransaction testOracle (effectiveItems c) (fun p tx => if p == 1 then { tx with store := phase1Store {} req } else tx) {}
  | .error _ => {}
-- non-ASCII names follow the byte-string convention everywhere
#guard tri (runReq "SecRule ARGS_GET_NAMES \"@streq é\" \"id:1,phase:1,pass\"\nSecRule ARGS_COMBINED_SIZE \"@eq 3\" \"id:2,phase:1,pass\"\nSecRule ARGS_GET:é \"@streq 1\" \"id:3,phase:1,pass,chain\"\n  SecRule MATCHED_VAR_NAME \"@streq ARGS_GET:é\" \"t:none\"\nSecRule REQUEST_COOKIES:é \"@streq 1\" \"id:4,phase:1,pass\"" { uri := "/?%C3%A9=1", headers := [("Cookie", "é=1")] }) == [1, 2, 3, 4]
-- escapes outside the Core subset do not compile
#guard (match Regex.compile "\\Zfoo" with | .error _ => true | .ok _ => false)   -- `\Z` is PCRE-only; `\A` is Core
#guard (match Regex.compile "(a)\\1" with | .error _ => true | .ok _ => false)
#guard (match Regex.compile "\\p{L}" with | .error _ => true | .ok _ => false)

-- persistent collections within one transaction (`05#persistent-collections`, `08#initcol`, `08#setvar`)
#guard tri (run "SecAction \"id:1,phase:1,pass,nolog,initcol:ip=%{REMOTE_ADDR},setvar:ip.hits=+1\"\nSecRule IP:hits \"@ge 1\" \"id:2,phase:1,pass\"" (demoStore [])) == [1, 2]
#guard tri (run "SecAction \"id:1,phase:1,pass,nolog,setvar:ip.hits=+1\"\nSecRule IP:hits \"@ge 1\" \"id:2,phase:1,pass\"\nSecRule &IP:hits \"@eq 0\" \"id:3,phase:1,pass\"" (demoStore [])) == [1, 3]
#guard tri (run "SecAction \"id:1,phase:1,pass,nolog,initcol:ip=%{REMOTE_ADDR},setvar:ip.hits=+1,setvar:ip.hits=+1,expirevar:ip.hits=60\"\nSecRule IP:hits \"@eq 2\" \"id:2,phase:1,pass\"\nSecRule &TX:hits \"@eq 0\" \"id:3,phase:1,pass\"" (demoStore [])) == [1, 2, 3]

-- tag exceptions are exact (ADR-0029): a tag that merely contains the parameter is not selected
#guard tri (run "SecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,pass,tag:'app/foo'\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:2,phase:1,pass,tag:'app/foobar'\"\nSecRuleRemoveByTag app/foo\nSecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:1,pass,nolog,ctl:ruleRemoveByTag=app/bar\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:4,phase:1,pass,tag:'app/bar'\"\nSecRule ARGS_GET:a \"@streq 1\" \"id:5,phase:1,pass,tag:'app/barbaz'\"" (demoStore [("a", "1")])) == [2, 3, 5]

-- negation applies per value (ADR-0030): one value failing the operator matches the rule
#guard tri (run "SecRule ARGS_GET:a \"!@streq abc\" \"id:1,phase:1,pass\"\nSecRule ARGS_GET:a \"!abc\" \"id:2,phase:1,pass\"" (demoStore [("a", "abc"), ("a", "zzz")])) == [1, 2]
#guard tri (run "SecRule ARGS_GET:a \"!@streq abc\" \"id:1,phase:1,pass\"" (demoStore [("a", "abc"), ("a", "ABC")])) == [1]
#guard tri (run "SecRule ARGS_GET:a \"!@streq abc\" \"id:1,phase:1,pass\"" (demoStore [("a", "abc")])) == []
-- ctl:requestBodyProcessor sets REQBODY_PROCESSOR at once, body or not (05#reqbody_processor)
#guard tri (runReq "SecRule REQUEST_HEADERS:Content-Type \"@beginsWith application/json\" \"id:1,phase:1,pass,nolog,ctl:requestBodyProcessor=JSON\"\nSecRule REQBODY_PROCESSOR \"@streq JSON\" \"id:2,phase:2,pass\"" { uri := "/", headers := [("Content-Type", "application/json")] }) == [1, 2]

-- an unset scalar yields one empty value (`05`): a negated operator matches and `&` counts 1
#guard tri (runReq "SecRule REQBODY_PROCESSOR \"!@streq JSON\" \"id:1,phase:2,pass\"\nSecRule &REQBODY_PROCESSOR \"@eq 1\" \"id:2,phase:2,pass\"\nSecRule &ARGS_GET \"@eq 0\" \"id:3,phase:1,pass\"" { uri := "/" }) == [3, 1, 2]

end SecLang
