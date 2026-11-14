# ADR-0045: `\"` and `\\` are unescaped in every double-quoted argument

- **Status:** proposed
- **Date:** 2026-11-14
- **Deciders:** @airween
- **Category:** Divergence

## Context

`01-lexical.md#quoting-and-escapes` already says that `\"` inside a double-quoted
argument yields `"`, but left the pair `\\` **not specified** and did not say which
arguments the rule covers. The engines read a quoted directive argument in three
different ways:

- **ModSecurity v2** never sees the raw text. Every one of its directives is declared
  `TAKE1`, `TAKE2`, `TAKE23`, `ITERATE` or `FLAG` (`apache2/apache2_config.c`; none is
  `RAW_ARGS`), so Apache splits the line with `ap_getword_conf()` and passes each word
  through `substring_conf()` (`server/util.c`, httpd 2.4.x and trunk; a copy is in
  `standalone/config.c` for the nginx and IIS builds). In a quoted word, `\\` becomes `\`
  and `\"` becomes `"`; any other backslash is kept. In a bare word `\\` also becomes `\`.
  This applies to the variables, the operator and the action list of `SecRule` alike,
  and to every other directive. It is fixed by the web server and cannot be changed in
  the module.
- **libmodsecurity v3** (v3.0.17, unchanged on `v3/master`) unescapes nothing.
  `src/parser/seclang-scanner.ll` counts the backslashes before a quote correctly to find
  the end of the argument (`FREE_TEXT_DOUBLE_QUOTE_MACRO_EXPANSION`), but hands the text
  on verbatim. An operator such as `@contains <h1 style=\"x\">` therefore compares
  against the backslashes and never matches the HTML it was written for (OWASP CRS rule
  955350 has exactly this shape), and `\\` stays two characters. Inside a single-quoted
  `setvar` value of a quoted action list, `\"` is a parse error ("Invalid input"),
  while the same pair in `msg` is accepted and kept.
- **Coraza** (v3.8.1) unescapes `\"` in the operator only:
  `internal/seclang/rule_parser.go`, `parseActionOperator`, runs the operator through
  `UnescapeQuotedString` (`internal/strings/strings.go`), which handles `\"` and nothing
  else, while the action list only loses its outer quotes (`MaybeRemoveQuotes`). `\\`
  stays two characters everywhere.

Run against the two new profiles below, `adapters/coraza` and `adapters/libmodsecurity`
confirm the v3 and Coraza lines; the v2 line follows from the Apache source and is checked
by `adapters/modsecurity2` in CI.

OWASP CRS v4.30.0 has 87 lines with `\"` (most in `@rx`, where PCRE reads `\"` and `"`
alike; one `@contains`, rule 955350; one `msg`, rule 942220) and none with `\\`: its
`CONTRIBUTING.md` asks for `\x5c` because the engines disagree.

There is a second, independent layer that this ADR does not change: inside a
single-quoted action value, `\'` yields `'` (`02-grammar.md#action-list`). ModSecurity v2
also accepts `\\` there and rejects any other backslash pair ("Invalid quoted pair",
`apache2/re.c`, `msre_parse_generic`), so in v2 a single backslash inside a
single-quoted action value has to be written `\\\\` in the rule file.

A related layer outside the engines: rules written inline in the nginx configuration
(`modsecurity_rules '…'` of the ModSecurity-nginx connector) are first unescaped by
nginx's own reader (`src/core/ngx_conf_file.c`, `ngx_conf_read_token`: `\"`, `\'`, `\\`,
`\t`, `\r`, `\n`), so the same rule text means something else inline than in a file
loaded with `modsecurity_rules_file`. That is a connector matter and out of scope here.

## Decision

1. Inside a double-quoted directive argument, `\"` MUST yield `"` and `\\` MUST yield
   `\`. A backslash before any other character MUST be passed through unchanged. A quote
   preceded by an odd number of backslashes is escaped; after an even number it ends the
   argument.
2. This MUST apply to every double-quoted argument of every directive, including the
   variables, the operator and the action list of `SecRule`, and the action lists of
   `SecAction` and `SecDefaultAction`. The escapes are removed once, before the directive
   interprets the argument; the single-quoted action-value layer of
   `02-grammar.md#action-list` then applies to the result.
3. Whether `\\` collapses in a **bare** token stays not specified.

This is the ModSecurity v2 behaviour, which is fixed by the web server.

## Options considered

- **Chosen: follow Apache's `substring_conf()` for quoted arguments.** The only option
  every engine can reach: v2 cannot change, v3 and Coraza can. It also makes `\\` a
  portable way to write a backslash, and makes CRS rule 955350 work in v3.
- **Specify `\\` as two characters (the v3 and Coraza behaviour).** Rejected:
  ModSecurity v2 could never conform, since Apache unescapes before the module runs.
- **Leave `\\` not specified and limit `\"` to the operator.** Rejected: the same text
  would mean `"` in the operator and `\"` in the action list of the same rule, and rule
  authors would keep needing `\x5c` and `\x22` workarounds.
- **Also collapse `\\` in bare tokens (full Apache parity).** Not chosen for now: an
  unquoted `@rx` pattern is rare in practice but would change meaning in v3 and Coraza,
  and nothing portable depends on it. Left open for a later ADR.

## Consequences

- For ModSecurity v2: none; this is its behaviour.
- For libmodsecurity v3: unescape `\"` and `\\` for every double-quoted argument, in one
  place in the scanner rather than per state, and accept `\"` inside single-quoted
  action values. Rules that today rely on `\"` matching a backslash and a quote (for
  example `@contains \"` to spot escaped JSON) match a bare quote afterwards; negated
  rules flip. The meaning of `\"` inside `\Q…\E` in `@rx` changes the same way. An open
  pull request fixes the operator part for `\"` only (owasp-modsecurity/ModSecurity#3753,
  for #3750).
- For Coraza: unescape the action list too, and collapse `\\` in `UnescapeQuotedString`.
- For rule authors: `\"` and `\\` mean the same in every engine and in every argument.
  Writing `\x22` and `\x5c` in regular expressions keeps working and stays the safe
  choice until the engines have shipped the change. A literal backslash immediately
  before a quote is written `\\\"`.
- For OWASP CRS v4.30: no rule contains `\\`; rule 955350 starts matching in v3; the
  `msg` of rule 942220 is logged without backslashes in v3 and Coraza.

## Tests

- `tests/engine/lexical/quoted-arguments.yaml`
- `tests/engine/lexical/quoted-argument-backslash.yaml`
- `tests/engine/lexical/quoted-argument-escapes-in-actions.yaml`

## References

- Apache httpd `server/util.c` (`ap_getword_conf`, `substring_conf`) and
  `server/config.c` (`invoke_cmd`)
- owasp-modsecurity/ModSecurity#3750, owasp-modsecurity/ModSecurity#3753
- <https://github.com/digitalwave/msc_retest#parsing>
- OWASP CRS `CONTRIBUTING.md` (`\x5c` for a literal backslash)
