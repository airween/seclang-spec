# ModSecurity v2 Reference Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run `tests/engine` and `tests/unit` against ModSecurity v2.9.15 in CI, gated by `compat/known-gaps.md`, so the v2 rows stop being predictions.

**Architecture:** A Python `unittest` adapter under `adapters/modsecurity2`, run inside the
`adapters/modsecurity2/Dockerfile` image. The unit tier shells out to v2's `msc_test`; the
engine tier starts `apache2 -X` with `mod_security2.so` per profile, proxies every request to
an in-process stub backend, and reads triggered rules from the debug log. Data loading,
gating rows, stage checking and the `re_groups` rule text are imported from
`adapters/libmodsecurity` (engine-neutral, and `mscapi` only loads its library when
`ModSecurity()` is constructed).

**Tech Stack:** Python ≥3.10 stdlib (`subprocess`, `socket`, `http.server`, `threading`), `pyyaml` (already a dev dependency), Docker, Debian bookworm Apache 2.4, ModSecurity v2.9.15.

**Spec:** `docs/superpowers/specs/2026-11-09-modsecurity2-adapter-design.md`

## Global Constraints

- ModSecurity `v2.9.15` (`v2/master` at `151074ac`); image built from `adapters/modsecurity2/Dockerfile`, which sets `MODSECURITY2_HTTPD=/usr/sbin/apache2`, `MODSECURITY2_MODULE=/usr/lib/apache2/modules/mod_security2.so`, `MODSECURITY2_MSC_TEST=/usr/local/bin/msc_test`, `UV_PROJECT_ENVIRONMENT=/opt/venv`.
- Without `MODSECURITY2_HTTPD` (engine and `re_groups`) or `MODSECURITY2_MSC_TEST` (unit) the conformance tests skip; `test_adapter.py` pure tests always run.
- Python only through `uv`; no new dependency.
- Engine name in known-gaps rows: `ModSecurity v2` (`ENGINE = "ModSecurity v2"`).
- Module names must not collide with `adapters/libmodsecurity` modules imported from it (`data`, `gaps`, `engine_tier`, `unit_tier`, `mscapi`): v2 modules are `httpd.py`, `v2_engine.py`, `v2_unit.py`.
- Generated conf: `ServerName localhost`; modules `mpm_event`, `authz_core`, `unique_id`, `remoteip`, `proxy`, `proxy_http`, `security2`; `RemoteIPHeader X-Seclang-Remote-Addr` + `RemoteIPInternalProxy 127.0.0.1`; `SecDebugLog` + `SecDebugLogLevel 4` appended after the profile's rules.
- Engine facts in new known-gaps rows carry a source pointer into `v2/master` (`apache2/…` file and symbol).
- Third-party actions in workflows pinned as the existing jobs pin them.

## Review Focus

1. **A request Apache rejects before ModSecurity** (malformed request line, odd method, `..` in URI) shows up as a 400 with no rule lines: it must be reported as `apache rejected the request (status N)`, not as "no interruption"/"rule not triggered". Test in Task 2.
2. **`remote_addr` other than 127.0.0.1, including IPv6** (`ipmatch.yaml`, `remote-addr-unique-id.yaml`): sent as `X-Seclang-Remote-Addr`; probed working on 2.9.15 for IPv4 and IPv6, header stripped before rules see it. Test in Task 2 (request bytes contain the header only when `remote_addr != "127.0.0.1"`).
3. **Body-limit interruptions** (`secrequestbodylimit-reject.yaml`, `secresponsebodylimit-reject.yaml`) have no `[id]` line: an HTTP status ≥ 400 with no `Access denied` line becomes `Interruption(0, "deny", status)`. Test in Task 2.
4. **httpd fails to start or hangs** (bad rules, port race): `apache2 -t` first; start waits for the port with a 10 s ceiling and raises with the error-log tail; every profile stops its httpd in `finally`. Test in Task 1.
5. **A `\` or non-printable byte in a unit param or expected output**: `msc_escape` writes every byte outside 0x21–0x7e and every `\` as `\xNN`. Test in Task 3.

---

### Task 1: httpd harness and stub backend

**Files:**
- Create: `adapters/modsecurity2/httpd.py`
- Create: `adapters/modsecurity2/test_adapter.py`
- Modify: `adapters/modsecurity2/Dockerfile` (already exists; no change expected unless a module is missing)

**Interfaces:**
- Produces:
  - `ENV_HTTPD = "MODSECURITY2_HTTPD"`, `ENV_MODULE = "MODSECURITY2_MODULE"`
  - `class StartError(Exception)` (message = reason + error-log tail)
  - `class Backend` — context manager; `Backend().port: int`; `Backend.respond(r: data.Response | None) -> None` sets what the next requests get (`None` → 200, empty body).
  - `def write_root(root: Path, profile_rules: str, files: dict[str, str], backend_port: int) -> tuple[Path, int]` — writes `files:`, `rules.conf`, `httpd.conf`; returns `(conf_path, listen_port)`.
  - `def configtest(conf: Path) -> str | None` — `apache2 -t -f conf`; `None` if OK, else stderr.
  - `class Httpd` — context manager `Httpd(conf: Path, port: int)`; starts `apache2 -X -f conf`, waits until the port accepts (10 s), `StartError` on timeout/exit; stops with SIGTERM + wait in `__exit__`.
  - Root layout: `<root>/debug.log`, `<root>/error.log`, `<root>/data/`, `<root>/tmp/`.

- [ ] **Step 1: Write the failing tests** in `test_adapter.py` (`sys.path.insert(0, <repo>/adapters/libmodsecurity)` after the module's own dir):
  - `test_conf_has_required_modules`: `write_root(tmp, "SecRuleEngine On", {}, 9)`; conf text contains each module name from Global Constraints, `ServerName localhost`, `RemoteIPHeader X-Seclang-Remote-Addr`, `ProxyPass / http://127.0.0.1:9/`, and `SecDebugLogLevel 4` appears after `Include` of `rules.conf`.
  - `test_files_written_relative`: `files={"sub/x.data": "a\n"}` → `tmp/"sub/x.data"` exists with that content.
  - `test_backend_serves_response` (pure, no httpd): `Backend` with `Response(201, {"X-A": "b"}, "hi")` → `http.client` GET gets 201, header `X-A: b`, body `hi`; after `respond(None)` → 200, empty body.
  - `test_httpd_start_and_proxy` (skip unless `ENV_HTTPD`): start with `SecRuleEngine On` → GET `/` returns the backend's status.
  - `test_httpd_bad_rules` (skip unless `ENV_HTTPD`): `configtest` on rules `SecFoo bar` returns non-`None`.
- [ ] **Step 2: Run** `uv run python -m unittest discover -s adapters/modsecurity2 -p test_adapter.py` → FAIL (`No module named 'httpd'`).
- [ ] **Step 3: Implement `httpd.py`** per the Interfaces block. Free ports from `socket.bind(("127.0.0.1", 0))`. `Backend` is a `ThreadingHTTPServer` on port 0 whose handler answers every method (`do_GET`/`do_POST`/… via `__getattr__` or explicit set: GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH) from the current `Response`, reading and discarding any request body.
- [ ] **Step 4: Run** pure tests on the host, then all in the image:
  `docker build -t seclang-modsecurity2 adapters/modsecurity2 && docker run --rm -v "$PWD":/repo seclang-modsecurity2 uv run python -m unittest discover -s adapters/modsecurity2 -p test_adapter.py -v` → all PASS, none skipped.
- [ ] **Step 5: Commit** `feat(modsecurity2): httpd harness and stub backend` (with Dockerfile and the design doc).

### Task 2: engine tier

**Files:**
- Create: `adapters/modsecurity2/v2_engine.py`
- Modify: `adapters/modsecurity2/test_adapter.py`

**Interfaces:**
- Consumes: Task 1 (`write_root`, `configtest`, `Httpd`, `Backend`, `StartError`); `data.Profile/Stage/Input/Interruption`; `engine_tier.Observed`, `engine_tier.check_stage` from `adapters/libmodsecurity`.
- Produces:
  - `def parse_debug_log(data: bytes) -> tuple[set[int], tuple[int, str] | None]` — triggered ids, first disruptive `(id, action)`.
  - `def request_bytes(i: data.Input) -> bytes`
  - `def send(port: int, raw: bytes) -> tuple[int | None, dict[str, str]]` — `None` status when the connection closed with no bytes.
  - `def run_profile(p: data.Profile, backend: Backend) -> list[str]` — failures in words, same shape as v3's `test_conformance.run_profile`.

Match messages (probed on 2.9.15; level in brackets is the debug level, ignore it when matching):

| Line prefix after `[N] ` | Result |
|---|---|
| `Warning. ` | triggered |
| `Access denied with code ` | triggered; disruptive `deny` |
| `Access denied with connection close` | triggered; disruptive `drop` |
| `Access denied with redirection to ` | triggered; disruptive `redirect` |
| `Access allowed ` | triggered; not an interruption |

The id is the `[id "N"]` on the same line; lines without one are ignored.

- [ ] **Step 1: Write the failing tests** (fixtures are lines copied from the probe in the design doc §4):
  - `test_parse_pass_nolog_chain`: lines for ids 1 (`Warning. Unconditional match in SecAction.`), 4 (chain), 5 plus `Continuing execution after rule id="END".` → `({1, 4, 5}, None)`.
  - `test_parse_deny`: adds `Access denied with code 403 (phase 2). … [id "7"]` → `7 in triggered`, disruptive `(7, "deny")`.
  - `test_parse_drop_redirect_allow`: drop line id 12 → `(12, "drop")`; redirect line id 13 → `(13, "redirect")`; allow line id 11 → triggered `{11}`, disruptive `None`.
  - `test_parse_ignores_recipe_lines`: `Recipe: Invoking rule ffff; [id "3"].` + `Rule returned 0.` → `(set(), None)`.
  - `test_request_bytes`: `Input(method="POST", uri="/a?b=1", headers={"Content-Type": "x"}, data="é")` → starts `b"POST /a?b=1 HTTP/1.1\r\n"`, has `Host: localhost`, `Content-Length: 2`, `Connection: close`, ends `b"\r\n\r\n\xc3\xa9"`; no `X-Seclang-Remote-Addr`. With `remote_addr="2001:db8:1::5"` → contains `X-Seclang-Remote-Addr: 2001:db8:1::5`. A profile-supplied `Host` or `Content-Length` is not duplicated.
  - `test_interruption_without_rule` (pure helper `interruption(status, disruptive) -> Interruption | None`): `(413, None)` → `Interruption(0, "deny", 413)`; `(200, None)` → `None`; `(None, (12, "drop"))` → `Interruption(12, "drop", 0)`; `(302, (13, "redirect"))` → `Interruption(13, "redirect", 302)`; `(400, None)` with the stage's error-log segment lacking any `ModSecurity:` line → reported failure `apache rejected the request (status 400)` from `run_profile`.
- [ ] **Step 2: Run** `uv run python -m unittest discover -s adapters/modsecurity2 -p test_adapter.py` → the new tests FAIL.
- [ ] **Step 3: Implement `v2_engine.py`.** `run_profile`: `expect_error` profiles → `configtest` result decides (as v3: error expected and got → `[]`); otherwise one `Httpd` per profile, per stage: `backend.respond(stage.response)`, record `debug.log`/`error.log` sizes, `send`, sleep-free read of the new segments (httpd `-X` has flushed by the time the response or close arrives; if a phase-5 rule is missing in practice, wait for the `Recording persistent data` line), build `Observed(triggered, interruption, error_log_segment)`, `engine_tier.check_stage`. Data is UTF-8 (engine-tier contract).
- [ ] **Step 4: Run** in the image: `docker run --rm -v "$PWD":/repo seclang-modsecurity2 uv run python -m unittest discover -s adapters/modsecurity2 -p test_adapter.py -v` → PASS. Then a one-profile smoke: `… uv run python -c "import sys; sys.path[:0]=['adapters/modsecurity2','adapters/libmodsecurity']; import data, httpd, v2_engine; p=[p for p in data.load_profiles(data.repo_root()) if p.path.endswith('processing/disruptive-actions.yaml')][0]; b=httpd.Backend().__enter__(); print(v2_engine.run_profile(p, b))"` → `[]`.
- [ ] **Step 5: Commit** `feat(modsecurity2): engine tier over Apache httpd`.

### Task 3: unit tier

**Files:**
- Create: `adapters/modsecurity2/v2_unit.py`
- Modify: `adapters/modsecurity2/test_adapter.py`

**Interfaces:**
- Consumes: `data.UnitCase`, `data.latin1`; `unit_tier.unit_rules`, `unit_tier.messages`, `unit_tier.check_unit`, `unit_tier.UnitResult` from `adapters/libmodsecurity`; Task 1 harness for `re_groups`.
- Produces:
  - `ENV_MSC_TEST = "MODSECURITY2_MSC_TEST"`
  - `def msc_escape(s: str) -> str` — byte string → `msc_test -p` argument.
  - `def msc_test_args(c: data.UnitCase) -> list[str]` — tfn: `["-t","tfn","-n",name,"-p",msc_escape(output)]`; op: `["-t","op","-n",name,"-p",msc_escape(param or ""),"-r",str(ret)]`.
  - `def run_unit_file(cases: list[data.UnitCase], backend: Backend) -> list[str]` — `msc_test` for cases without `re_groups` (stdin = `latin1(input)`, exit 0 = pass, else the failure is `t:NAME`/`@NAME param` + msc_test's stderr); cases with `re_groups` through httpd: `write_root` with `unit_rules(c)` decoded Latin-1, POST the input as `application/octet-stream`, `messages(error_log_lines)` → `UnitResult` exactly as v3's `run_unit` builds it, then `check_unit`.

- [ ] **Step 1: Write the failing tests:**
  - `test_msc_escape`: `msc_escape("a\\b\x00\xff ~")` == `"a\\x5cb\\x00\\xff\\x20~"`.
  - `test_msc_test_args_tfn_op`: tfn `lowercase` output `"ab\x01"` → `["-t","tfn","-n","lowercase","-p","ab\\x01"]`; op `rx` param `None`, ret 0 → ends `["-p","","-r","0"]`.
  - `test_msc_test_runs` (skip unless `ENV_MSC_TEST`): one passing tfn case (`lowercase`, `"AB\x01"` → `"ab\x01"`) → `[]`; same case with output `"XYZ"` → one failure containing `Output:`.
  - `test_re_groups_case` (skip unless `ENV_HTTPD`): the first `re_groups` case of `tests/unit/operators/rx.json` → `[]`.
- [ ] **Step 2: Run** → FAIL (`No module named 'v2_unit'`).
- [ ] **Step 3: Implement `v2_unit.py`.** One `Httpd` per distinct `unit_tier.group_key(c)` among the `re_groups` cases of a file (12 cases total, so starting per case is acceptable if grouping complicates it).
- [ ] **Step 4: Run** in the image → PASS, none skipped.
- [ ] **Step 5: Commit** `feat(modsecurity2): unit tier through msc_test`.

### Task 4: gated conformance run and known-gaps

Precondition: rebase this branch onto local `main` once its v3.0.17 work and commits `42dc94c`, `64421ec` are on it (ask the user before rebasing; do not touch `compat/known-gaps.md` before that).

**Files:**
- Create: `adapters/modsecurity2/test_conformance.py`
- Modify: `compat/known-gaps.md`

**Interfaces:**
- Consumes: Tasks 2–3 (`v2_engine.run_profile`, `v2_unit.run_unit_file`), `gaps.load_gaps`, `data.load_profiles`, `data.load_unit_cases`.
- Produces: `ENGINE = "ModSecurity v2"`, `IMPLEMENTED: set[str]`, `UNSUPPORTED_OPERATORS/TRANSFORMATIONS/ANCHORS: set[str]`; `TestEngine.test_profiles`, `TestUnit.test_files` with the same `Gated.report` semantics as `adapters/libmodsecurity/test_conformance.py` (copy the class; importing that module would make discovery run v3's test classes).

- [ ] **Step 1: Write `test_conformance.py`** mirroring v3's: `setUpModule` skips without `ENV_HTTPD`/`ENV_MSC_TEST`; one module-level `Backend` started in `setUpModule`, closed in `tearDownModule`. `IMPLEMENTED` starts as `{"05-variables.md#persistent-collections"}`; the three `UNSUPPORTED_*` sets start empty (the existing `uppercase-extra.json` row stays a gap row until Step 3 decides).
- [ ] **Step 2: Run** in the image: `docker run --rm -v "$PWD":/repo seclang-modsecurity2 uv run python -m unittest discover -s adapters/modsecurity2 -p test_conformance.py 2>&1 | tee /tmp/v2-run.txt` and list: unlisted failing files, obsolete rows.
- [ ] **Step 3: Classify every result** per `AGENTS.md` ("When an adapter run disagrees with the spec"): engine divergence → known-gaps row naming `ModSecurity v2` with a `v2/master` source pointer; Apache-front rejection → adapter skip with a comment naming the Apache behaviour, never a gap row; spec/test defect → stop and report to the user before editing spec or tests; adapter defect → failing test in `test_adapter.py` first. Delete obsolete v2 rows. Extended features v2 lacks go into the `UNSUPPORTED_*` sets, not gap rows.
- [ ] **Step 4: Run** Step 2 again → `OK` (skips allowed only for `requires:`/`UNSUPPORTED_*`); `uv run python tools/validate.py` → `0 error(s)`.
- [ ] **Step 5: Commit** `test(modsecurity2): gate v2 by known-gaps; verify v2 rows`.

### Task 5: CI and documentation

**Files:**
- Modify: `.github/workflows/validate.yml`
- Create: `adapters/modsecurity2/README.md`
- Modify: `AGENTS.md`, `README.md`, `compat/known-gaps.md` (introduction), `site/` content adapter config if adapter READMEs are listed explicitly (check `site/` for `adapters/libmodsecurity/README.md`)

**Interfaces:**
- Consumes: the image and the commands of Tasks 1–4.

- [ ] **Step 1: Add job `modsecurity2-adapter`** to `validate.yml`: `actions/checkout` (pinned as the other jobs), `docker build -t seclang-modsecurity2 adapters/modsecurity2` with a build cache keyed on `hashFiles('adapters/modsecurity2/Dockerfile')` (use `actions/cache` on a `docker save` tarball, already pinned in this workflow, rather than adding a new action), then `docker run --rm -v "$PWD":/repo seclang-modsecurity2 uv run python -m unittest discover -s adapters/modsecurity2 -v`.
- [ ] **Step 2: Write `adapters/modsecurity2/README.md`** in the structure of `adapters/libmodsecurity/README.md`: commands, building (the image), how results are gated (same table, engine cell `ModSecurity v2`), how the tiers are driven (msc_test; httpd per profile, debug-log messages table, `X-Seclang-Remote-Addr`, stub backend), known limits (Apache front-end rejections; debug-log formats are 2.9.15's and pinned in `test_adapter.py`).
- [ ] **Step 3: Update prose:** `AGENTS.md` layout table gets an `adapters/modsecurity2/` row and the "Rows naming only ModSecurity v2 are predictions" sentence goes; `compat/known-gaps.md` introduction says all three engines are verified; `README.md` status lists three adapters; the "Before you commit" block gets the docker command. If the site lists adapter READMEs, add this one and run `hugo -s site --gc --minify --cleanDestinationDir && site/smoke.sh`.
- [ ] **Step 4: Run** `uv run python tools/validate.py` → `0 error(s)`; `uv run python -m unittest discover -s tools -t .` → OK; the docker command from Step 1 → OK.
- [ ] **Step 5: Commit** `ci(modsecurity2): run the v2 adapter in CI; document it`.
