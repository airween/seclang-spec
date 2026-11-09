# ModSecurity v2 reference adapter

Runs the conformance data in `../../tests` against
[ModSecurity](https://github.com/owasp-modsecurity/ModSecurity) v2.9.15 as `unittest`,
inside the container image `Dockerfile` builds: Debian bookworm, Apache httpd 2.4,
`mod_security2.so` and v2's own unit tester `msc_test`, both built from the `v2.9.15` tag.

```sh
docker build -t seclang-modsecurity2 adapters/modsecurity2
docker run --rm -v "$PWD":/repo seclang-modsecurity2 \
  uv run python -m unittest discover -s adapters/modsecurity2                       # everything
docker run --rm -v "$PWD":/repo seclang-modsecurity2 \
  uv run python -m unittest discover -s adapters/modsecurity2 -p test_adapter.py    # adapter self-tests
```

The image sets `MODSECURITY2_HTTPD`, `MODSECURITY2_MODULE` and `MODSECURITY2_MSC_TEST`;
without them (on the host) the conformance tests and the engine smoke tests are skipped.
Its virtual environment lives in `/opt/venv`, so the host's `.venv` is left alone.

v2 has no library API to drive in-process: `standalone/` does not link on `v2/master`
(the fix is unmerged on `v2/issue-3451-standalone-link`), so the adapter runs the module
the way it is deployed, under Apache. `data.py`, `gaps.py`, `engine_tier.check_stage` and
`unit_tier.unit_rules` are imported from `../libmodsecurity`; they do not load the v3
library.

## How results are gated

`compat/known-gaps.md` is the expected-failure list; rows whose Engine cell names
`ModSecurity v2` apply. For each test file:

| Row for this engine | Result | Outcome |
|---|---|---|
| none | all pass | pass |
| none | any failure | **fail** (a real defect in the engine or in the specification) |
| present | any failure | pass, failures printed as `expected (known gap: …)` |
| present | all pass | **fail** with `known-gaps row is obsolete` (remove the row) |

Extended features v2 does not implement are skipped, not failed: profiles through
`requires:` (`IMPLEMENTED` in `test_conformance.py`), unit files through the
`UNSUPPORTED_*` sets (empty for v2.9.15).

## How the tiers are driven

- **Engine tier** (`v2_engine.py`, `httpd.py`): per profile a temporary `ServerRoot`
  holds the profile's `files:`, its rules and an `httpd.conf` that loads `mpm_event`,
  `authz_core`, `unique_id` (v2 refuses every request without it), `remoteip`, `proxy`,
  `proxy_http` and `security2`, proxies every request to a stub backend and appends
  `SecDebugLog`/`SecDebugLogLevel 4` after the rules. `apache2 -t` decides
  `expect_error`; then `apache2 -X` (one process, so the debug log is in request order)
  serves the profile's stages. Each stage is sent raw over a socket; the backend answers
  with the stage's `response` (or `200`, empty), so phases 3–5 run.
  - *Triggered rules*: v2.9.15 writes one debug-log line per matched rule, `nolog`
    included, and for a chain only when every member matched (with the head's id). The
    adapter reads the `[id "N"]` of every line starting `Warning. ` or `Access `.
  - *Interruption*: `Access denied with code N` (deny), `with connection close` (drop),
    `with redirection to URL using status N` (redirect), `using proxy to` (proxy). The
    status is v2's own from that line: Apache answers 500 for a code it has no reason
    phrase for (418). An error status with no such line is v2's (`rule_id: 0`) only when
    v2 wrote a non-rule `ModSecurity:` message to the error log (a body limit, a body
    processor error); any other status the backend was not asked for is reported as
    `Apache answered N without ModSecurity`, not as an engine result. Rule messages alone
    do not count: Apache rejects `..` in a URI after phase 1 has run.
  - *Client address*: a `remote_addr` other than `127.0.0.1` is sent in
    `X-Seclang-Remote-Addr`, which `mod_remoteip` turns into `REMOTE_ADDR` (IPv4 and IPv6)
    and removes before rules see `REQUEST_HEADERS`.
  - *Logs*: phase 5 runs after the response is sent, so each stage waits (up to 2 s) for
    the logging phase's `Audit log: …` line. `log_contains` searches the error log, where
    v2 writes its `ModSecurity:` messages.
- **Unit tier** (`v2_unit.py`): `msc_test -t tfn|op -n NAME -p PARAM [-r RET]` with the
  input on stdin as raw bytes; `-p` is escaped as `\xNN` for every byte outside 0x21–0x7e
  and every `\` (`tests/msc_test.c` decodes it). Exit 0 is a pass. `msc_test` reports only
  the operator's return code, so the `re_groups` cases run through httpd with the v3
  adapter's capture rules plus `ctl:forceRequestBodyVariable=On` (v2 leaves `REQUEST_BODY`
  absent without a body processor, ADR-0022); those whose parameter holds a control
  character cannot be written as a directive and fall back to `msc_test` (match result
  only).

## Known limits

- The debug-log formats are those of v2.9.15; `test_adapter.ParseDebugLogTests` pins them.
- Apache sits in front of the engine: a request it rejects (malformed request line, `%`
  not followed by two hex digits, `..` above the root) never completes in v2. Such a
  failure says so and is never a known-gaps row; it waits the full 2 s for a logging
  phase that does not come.
- Each profile starts its own httpd (about 0.1 s); the whole run takes about 25 s.
