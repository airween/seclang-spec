# 01. Lexical structure

SecLang configuration is line-oriented text. This file defines how lines become
directives; `02-grammar.md` defines what a directive line may contain.

### Lines and directives

**Status:** Core

**Syntax.** A configuration file is a sequence of lines separated by LF or CRLF. After
line continuation (below) each logical line is empty, a comment, or one directive. A
directive is a name followed by zero or more whitespace-separated arguments.

**Semantics.** Engines MUST accept both LF and CRLF line endings. Leading and trailing
whitespace on a line is ignored. Empty lines are ignored. The character encoding of a
configuration file is bytes; engines MUST NOT reject non-ASCII bytes inside quoted
arguments (operator parameters routinely contain them).

**Divergence notes.** None known.

**Tests.** `tests/engine/lexical/crlf-line-endings.yaml`

### Comments

**Status:** Core

**Syntax.** A logical line whose first non-blank character is `#` is a comment.

**Semantics.** Comment lines are discarded before any directive is parsed. There are no
trailing comments: a `#` anywhere after the first non-blank character is data and
reaches the directive unchanged. Because line continuation is applied first, a comment
line ending in `\` continues onto the next physical line and the whole logical line is
the comment; engines MUST NOT parse the continued text as a directive (ADR-0013).

**Divergence notes.** ModSecurity v2 (Apache joins continuation lines before testing
for `#`) and libmodsecurity v3 (`src/parser/seclang-scanner.ll` enters a comment state
on `# SecRule … \`) behave as specified. Coraza 3.8.1 drops the comment line before
testing for a trailing backslash (`internal/seclang/parser.go`, the `#` check precedes
the continuation check), so the continued text is parsed as a new directive. A
commented-out multi-line rule therefore comes back to life in Coraza. See ADR-0013.

**Tests.** `tests/engine/lexical/comment-lines.yaml`,
`tests/engine/lexical/comment-with-trailing-backslash.yaml`

### Line continuation

**Status:** Core

**Syntax.** A physical line whose last non-blank character is `\` continues onto the
next physical line.

**Semantics.** The backslash and the line break are removed and the two pieces are
joined with no inserted character. Whitespace before the backslash and leading
whitespace on the continuation line are kept as written; rule authors rely on this to
indent continued lines inside a quoted action list. Continuation may repeat over any
number of lines. OWASP CRS v4 contains over seven thousand continued lines, so this is
the most exercised lexical feature in practice.

**Divergence notes.** None known for directive lines. For comment lines see
`#comments` and ADR-0013.

**Tests.** `tests/engine/lexical/continuation-lines.yaml`

### Quoting and escapes

**Status:** Core

**Syntax.** A directive argument is either a bare token, which extends to the next
whitespace, or a string delimited by double quotes `"`. Inside double quotes, `\"` yields
a literal double quote without ending the argument, and `\\` yields a single backslash
(ADR-0045). A backslash before any other character is passed through to the directive
unchanged, so `\x5c`, `\d` or `\'` reach the directive as written. A quote preceded by an
odd number of backslashes is escaped; after an even number it ends the argument.

**Semantics.** The quotes are delimiters, not part of the argument. An argument that
contains whitespace, `"` or begins with `@` or `!` SHOULD be quoted. The two escapes are
removed from **every** double-quoted argument of **every** directive (the variables, the
operator and the action list of `SecRule`, the action list of `SecAction` and
`SecDefaultAction`, the arguments of `SecRuleUpdateActionById` and the like) before the
directive interprets it. They are removed once, at this level only: escapes inside a
single-quoted action value are a separate layer, defined in `02-grammar.md#action-list`.
Single quotes are not argument delimiters at this level. Whether `\\` collapses in a
**bare** token is **not specified**: Apache collapses it there too for ModSecurity v2,
libmodsecurity v3 and Coraza keep both characters. Until every engine implements
ADR-0045, portable rules write a literal backslash in a regular expression as `\x5c`, as
OWASP CRS does (its `CONTRIBUTING.md`).

**Divergence notes.** ModSecurity v2 receives every argument from Apache's
configuration reader (`server/util.c`, `ap_getword_conf` and `substring_conf`; the
standalone build carries a copy in `standalone/config.c`), which collapses both `\"` and
`\\`; this is the behaviour specified here. libmodsecurity v3 passes operator arguments
on verbatim (`src/parser/seclang-scanner.ll`, `FREE_TEXT_DOUBLE_QUOTE_MACRO_EXPANSION`,
appended with `appendText`), so `@streq say \"hi\" now` compares against the backslashes
too, keeps `\\` everywhere, and rejects `\"` inside a single-quoted `setvar` value of a
quoted action list. Coraza turns `\"` into `"` in the operator only
(`internal/seclang/rule_parser.go`, `parseActionOperator`, through
`UnescapeQuotedString`), keeps `\\`, and leaves the action list as written. Engines also
differ in how they parse `\"` inside the action list after macro expansion; a
libmodsecurity v3 fix for an escaped quote following a macro landed in 2026 and that case
is tested in `02-grammar.md`. The libmodsecurity v3 and Coraza gaps are listed in
`compat/known-gaps.md`.

**Tests.** `tests/engine/lexical/quoted-arguments.yaml`,
`tests/engine/lexical/quoted-argument-backslash.yaml`,
`tests/engine/lexical/quoted-argument-escapes-in-actions.yaml`

### Include

**Status:** Core

**Syntax.** `Include PATH`

**Semantics.** The file at `PATH` is parsed in place, as if its lines replaced the
`Include` line. If `PATH` contains `*`, it is a glob pattern; every matching file is
included in lexicographic order. Engines MUST support absolute paths and `*` globs. A
non-glob `PATH` that does not exist MUST be a configuration error. The outcome of a glob
that matches nothing is **not specified** (see the divergence note); portable
configurations only use globs that match at least one file. Included files may themselves
`Include`; an engine MAY cap the total number of included files, and the cap MUST be at
least 100.

The directory against which a *relative* `PATH` is resolved is **not specified**: see
the divergence note. Portable configurations use absolute paths or paths relative to a
directory the deployment controls.

**Divergence notes.** ModSecurity v2 uses the Apache `Include` directive, which resolves
relative paths against `ServerRoot`. libmodsecurity v3 and Coraza resolve them against
the directory of the including file (Coraza: `internal/seclang/parser.go`, which also
caps includes at 100 files via `maxIncludeRecursion`). Coraza only treats `PATH` as a
glob when it contains `*`; Apache also expands `?` and `[...]`. Only `*` is Core. An
empty glob is a configuration error in ModSecurity v2 (Apache 2.4 `Include`: "No matches
for the wildcard"; `IncludeOptional` is the lenient form) and libmodsecurity v3
(`seclang-scanner.ll`, "Not able to open file"), and only a warning in Coraza
(`parser.go`, "empty glob result").

**Tests.** `tests/engine/lexical/include-relative-file.yaml`

### Name matching

**Status:** Core

**Syntax.** Directive names (`SecRule`), operator names (`@contains`), action names
(`deny`, `t:`), transformation names (`lowercase`) and `ctl:` option names
(`ruleEngine`) are identifiers made of ASCII letters and digits.

**Semantics.** Engines MUST match all of these identifiers case-insensitively.
`secrule`, `SecRule` and `SECRULE` denote the same directive; `@CONTAINS` and
`@contains` the same operator; `T:LOWERCASE` and `t:lowercase` the same
transformation. The canonical spelling used in this specification is the mixed-case
form from the ModSecurity reference manual; engines SHOULD emit that spelling in logs
and error messages.

Variable and collection names (`ARGS`, `TX`) and collection keys are **not** covered by
this section; their case rules are defined with the variables (ADR-0008, Phase 3).

**Divergence notes.** ModSecurity v2 and v3 already behave this way. Coraza 3.8.1
matches directive, action and transformation names case-insensitively but operator
names case-sensitively. See ADR-0002.

**Tests.** `tests/engine/lexical/case-insensitive-names.yaml`
