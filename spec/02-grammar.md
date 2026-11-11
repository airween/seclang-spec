# 02. Grammar

This file defines what a logical line may contain once `01-lexical.md` has split the
configuration into lines, removed comments and joined continuations. The grammar is
given in EBNF. `WS` is one or more spaces or tabs; `NONWS` is any character except
whitespace; `IDENT` is one or more ASCII letters and digits; `CNAME` is one or more ASCII
letters, digits and underscores.

```ebnf
directive     = name , { WS , argument } ;
argument      = quoted | bare ;
quoted        = '"' , { qchar } , '"' ;        (* qchar: any char except '"', or the pairs \" and \\ *)
bare          = NONWS , { NONWS } ;

secrule       = "SecRule" , WS , argument , WS , argument , [ WS , argument ] ;
                                               (* variables, operator, actions *)
secaction     = "SecAction" , WS , argument ;  (* actions *)

variables     = variable , { "|" , variable } ;
variable      = [ "!" | "&" ] , collection , [ ":" , selector ] ;
collection    = CNAME ;
selector      = regexsel | key ;               (* for XML the selector is an XPath expression: 05-variables.md#xml *)
regexsel      = "/" , { rchar } , "/" ;        (* rchar: any char except an unescaped "/" *)
key           = kchar , { kchar } ;            (* kchar: any char except "|" and whitespace *)

operator      = [ "!" ] , "@" , opname , [ WS , opparam ]
              | [ "!" ] , opparam ;            (* implicit @rx *)
opname        = IDENT ;
opparam       = { any } ;                      (* to the end of the argument; may contain macros *)

actions       = action , { "," , action } ;
action        = aname , [ ":" , avalue ] ;
avalue        = "'" , { achar } , "'"          (* achar: any char except "'", or the pair \' *)
              | { vchar } ;                    (* vchar: any char except "," *)
aname         = IDENT ;

macro         = "%{" , collection , [ "." , key ] , "}" ;
```

### Directive line

**Status:** Core

**Syntax.** `directive` above.

**Semantics.** The first token is the directive name, matched case-insensitively
(`01-lexical.md#name-matching`). Arguments are separated by runs of whitespace; a quoted
argument may contain whitespace. The number and meaning of arguments is fixed per
directive and defined in `04-directives.md`. Too few or too many arguments MUST be a
configuration error. A directive name that this specification does not define MUST be a
configuration error (ADR-0005).

**Divergence notes.** Coraza 3.8.1 splits a directive line on the space character only
(`internal/seclang/parser.go`, `strings.Cut(l, " ")`; `rule_parser.go` likewise), so a
tab between arguments is a load error there; ModSecurity v2 and libmodsecurity v3 accept
tabs. `directive-line-whitespace.yaml` fails on Coraza (`compat/known-gaps.md`).

**Tests.** `tests/engine/grammar/directive-line-whitespace.yaml`,
`tests/engine/directives/unknown-directive.yaml`

### SecRule structure

**Status:** Core

**Syntax.** `secrule` and `secaction` above. The three positional arguments of
`SecRule` are the variable list, the operator and the action list; the action list MAY
be omitted. `SecAction` takes only an action list.

**Semantics.** A `SecRule` evaluates the operator against every value selected by the
variable list; it matches if the operator is true for at least one value. A `SecAction`
is an unconditional rule: it always matches. Every `SecRule` and `SecAction` that is not
a chain member MUST carry an `id` action, and ids MUST be unique within a
configuration; a missing or duplicate id MUST be a configuration error. Chain members
(`03-processing-model.md#chains`) MUST NOT carry `id`.

**Divergence notes.** ModSecurity v2 (`apache2/re.c`, "No action id present within the
rule") and libmodsecurity v3 (`src/parser/driver.cc`, "Rules must have an ID") reject a
rule without an id. Coraza 3.8.1 accepts it unless built with the
`coraza.rule.mandatory_rule_id_check` tag (`internal/corazawaf/rule_mandatory_idcheck*.go`);
all three reject duplicate ids. See ADR-0015.

**Tests.** `tests/engine/grammar/secrule-requires-id.yaml`,
`tests/engine/grammar/duplicate-rule-id.yaml`

### Variable list

**Status:** Core

**Syntax.** `variables` above. No whitespace is permitted around `|`.

**Semantics.** Each `variable` names a collection or a member of one. The list is the
union of the values selected by each entry, evaluated in list order. A leading `!`
removes the named member(s) from the values selected so far by the same collection; a
leading `&` replaces the values by a single value, the count of members selected; on a
scalar, which always holds one value, it counts 1 and MUST NOT be a configuration error
(ADR-0037). `&` and `!` are mutually exclusive on one entry. Collection names are matched
case-insensitively; the case rules for keys are defined in `05-variables.md`. A
collection name that this specification does not define MUST be a configuration error;
Engine-specific names are reserved, not defined (ADR-0005).

**Divergence notes.** ModSecurity v2 rejects `&` on variables registered as `VAR_SIMPLE`
(`apache2/re.c`, "The & modificator does not apply to non-collection variables."); see
ADR-0037.

**Tests.** `tests/engine/grammar/variable-list.yaml`,
`tests/engine/grammar/variable-count-and-exclusion.yaml`,
`tests/engine/variables/count-scalar.yaml`,
`tests/engine/grammar/unknown-variable.yaml`

### Variable selectors

**Status:** Core

**Syntax.** `selector` above: either a literal key or a regular expression between `/`.

**Semantics.** `COLLECTION:key` selects the member(s) whose name equals `key` under the
collection's key-comparison rule. `COLLECTION:/re/` selects every member whose name
matches the regular expression `re`; the expression is unanchored. A selector on a
collection that has no members (a scalar variable) MUST be a configuration error. For the
`XML` collection the selector is an XPath expression (`05-variables.md#xml`) and the two
forms above do not apply.

**Divergence notes.** The grammar lets a regular expression selector contain `|`
(`REQUEST_HEADERS:/^(?:x-a|x-b)$/`), as libmodsecurity v3 and Coraza do (both lex `/…/`
as one token); ModSecurity v2 (`apache2/re.c`, `msre_parse_generic`) ends an unquoted
selector at the first `|`, so such a selector is split there and the rule fails to load.
No profile exercises this (a v2 adapter would be needed to observe it); CRS v4 avoids it.
Whether `/` inside the expression may be escaped as `\/` is engine-dependent and not Core.

**Tests.** `tests/engine/grammar/variable-selectors.yaml`

### Operator

**Status:** Core

**Syntax.** `operator` above.

**Semantics.** An argument beginning with `@` names an operator; the rest of the
argument, after one run of whitespace, is its parameter. An argument that does not begin
with `@` or `!@` is the parameter of the implicit `@rx` operator. A leading `!` negates
the result per value: the rule matches when the operator is false for *at least one*
selected value, so at least one value must have been selected
(`06-operators.md#unconditionalmatch`, ADR-0030). Under `multiMatch` the negation applies to
each evaluation of a value (`08-actions.md#multimatch`). The
set of operators and their parameters is defined in `06-operators.md`. An unknown
operator name MUST be a configuration error.

**Divergence notes.** None known.

**Tests.** `tests/engine/grammar/operator-forms.yaml`

### Action list

**Status:** Core

**Syntax.** `actions` above.

**Semantics.** Actions are separated by commas. An action value either runs to the next
comma or is enclosed in single quotes, in which case it may contain commas and `\'`
denotes a literal single quote. Whitespace around an action name is ignored (CRS writes
`id:1, phase:1`). The same action name may appear more than once where the action is
cumulative (`t:`, `tag:`, `setvar:`, `ctl:`). `t:none` discards every transformation
inherited from `SecDefaultAction`. The actions themselves are defined in
`08-actions.md`. An unknown action name MUST be a configuration error.

**Divergence notes.** None known.

**Tests.** `tests/engine/grammar/action-list-values.yaml`

### Macro expansion

**Status:** Core

**Syntax.** `macro` above.

**Semantics.** `%{NAME}` expands to the value of the variable `NAME`; `%{COLL.key}`
expands to the member `key` of collection `COLL`. Names are matched case-insensitively.
An unset variable expands to the empty string. Expansion happens at evaluation time,
every time the rule runs. Macros expand in the values of the actions `setvar`, `msg`,
`logdata`, `tag`, `expirevar`, `initcol`, `redirect` and `exec` (as far as each is
Core; see `08-actions.md`) and in the parameter of these operators: `@beginsWith`,
`@contains`, `@endsWith`, `@eq`, `@ge`, `@gt`, `@le`, `@lt`, `@streq`, `@within`. A
macro in any other operator parameter is literal text in at least one engine and is
therefore not portable.

**Divergence notes.** Operator macro support beyond the Core list, by engine (surveyed
2026-10-06 from `re_operators.c`, `src/operators/*.cc`, `internal/operators/*.go`):
`@rx` v2 and v3; `@containsWord` v2 and v3; `@strmatch` v3 and Coraza; `@rsub` and
`@validateHash` v2 only; `@rxGlobal` v3 only. These are Extended per engine.

**Tests.** `tests/engine/grammar/macro-expansion.yaml`
