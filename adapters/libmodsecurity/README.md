# libmodsecurity v3 reference adapter

Runs the conformance data in `../../tests` against
[libmodsecurity](https://github.com/owasp-modsecurity/ModSecurity) v3 through its C API,
with `ctypes`, as `unittest`.

```sh
export MODSECURITY_LIB=/path/to/libmodsecurity.so   # or .dylib
uv run python -m unittest discover -s adapters/libmodsecurity                        # everything
uv run python -m unittest discover -s adapters/libmodsecurity -p test_conformance.py -v
uv run python -m unittest discover -s adapters/libmodsecurity -p test_adapter.py      # adapter self-tests
```

Without `MODSECURITY_LIB` the conformance tests and the engine smoke tests are skipped.

## Building the library

CI builds v3.0.17 from source (`.github/workflows/validate.yml`, job
`libmodsecurity-adapter`) and caches the install. The same recipe works locally; the
build needs the libxml2, yajl and PCRE2 development packages so that XML and JSON bodies
and the regex operators are available:

```sh
git clone --depth 1 -b v3.0.17 --recurse-submodules --shallow-submodules https://github.com/owasp-modsecurity/ModSecurity.git
cd ModSecurity && ./build.sh
./configure --prefix=$HOME/modsecurity --disable-doxygen-doc --disable-examples \
  --without-lua --without-lmdb --without-ssdeep --without-curl --without-geoip --without-maxmind
make -j"$(nproc)" && make install
export MODSECURITY_LIB=$HOME/modsecurity/lib/libmodsecurity.so
```

On macOS with Homebrew add `--with-pcre2=/opt/homebrew/opt/pcre2
--with-libxml=/opt/homebrew/opt/libxml2 --with-yajl=/opt/homebrew/opt/yajl` and point
`MODSECURITY_LIB` at `lib/libmodsecurity.dylib`.

## Differential run

`differential.py` replays the requests `adapters/coraza/cmd/differential` generated (with
what Coraza did) through libmodsecurity, writes what libmodsecurity did in the same JSON
shape for `seclang-eval`, and prints every request on which the two engines disagree:

```sh
MODSECURITY_LIB=… uv run python adapters/libmodsecurity/differential.py formal/.lake/differential.json --out formal/.lake/v3.json
cd formal && lake exe seclang-eval .lake/v3.json
```

Profiles with a libmodsecurity row in `compat/known-gaps.md` are skipped. An engine
disagreement means at least one engine diverges from the specification on that request;
`seclang-eval` on the two files says which, and the divergence then gets a Core profile and
a known-gaps row like any other. CI runs it after the Lean job on the same generated file.

## How results are gated

`compat/known-gaps.md` is the expected-failure list; rows whose Engine cell names
`libmodsecurity v3` apply. For each test file:

| Row for this engine | Result | Outcome |
|---|---|---|
| none | all pass | pass |
| none | any failure | **fail** (a real defect in the engine or in the specification) |
| present | any failure | pass, failures printed as `expected (known gap: …)` |
| present | all pass | **fail** with `known-gaps row is obsolete` (remove the row) |

Extended features the library does not implement are skipped, not failed: profiles
through `requires:`, unit files through the `UNSUPPORTED_*` sets in `test_conformance.py`
(empty for v3.0.17 built as above).

## How the tiers are driven

- **Engine tier** (`engine_tier.py`): the profile's `files:` and its rules are written
  under a temporary directory and loaded with `msc_rules_add_file`, so relative `Include`
  paths resolve. `SecDebugLog`/`SecDebugLogLevel 4` are appended because the C API has no
  "matched rules" call that includes `nolog` rules; the debug-log segment written during
  the stage is parsed for `(Rule: N)`, `Rule returned 0|1.`, `Executing unconditional
  rule` and `Running (disruptive) action:` lines. `interruption` combines that with
  `msc_intervention` (status, URL); `block` is resolved to `redirect` when the
  intervention carries a URL and to `deny` otherwise. `log_contains` searches the
  error-log callback lines plus the intervention's own log line (v3 routes a denying
  rule's message there).
- **Unit tier** (`unit_tier.py`): each case is a rule over `REQUEST_BODY` carrying `log`;
  the input is sent as raw bytes (unit strings are Latin-1 byte strings). Transformation
  output is read from the error log through `t:hexEncode,msg:'%{MATCHED_VAR}'`, which is
  binary safe and untruncated; `re_groups` through one `TX:i` rule per group. Parameters
  are inserted verbatim: v3 keeps `\\` pairs and treats `\"` as two characters, and no
  unit parameter contains `"`.

## Known limits

- An engine crash cannot be caught from `ctypes` and aborts the run.
- The debug-log line formats are those of v3.0.17; a release that changes them needs
  `engine_tier.parse_debug_log` updated (its tests in `test_adapter.py` pin the formats).
- In-memory persistent collections are process-global in libmodsecurity, so profiles
  that use `initcol` share state within one run; only one profile does today.
