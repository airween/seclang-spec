# ModSecurity v2 Reference Adapter — Design

Status: driver chosen in conversation, 2026-11-09; rest of the design pending review.

## 1. Brief

**You said.** Find out how to build the testing engine for ModSecurity v2.

**Agreed.** A Python module under `adapters/modsecurity2` that runs the conformance data
in `tests/` against ModSecurity v2.9.15 (`v2/master` at `151074ac`), as `unittest`, in
CI, with `compat/known-gaps.md` as the expected-failure list exactly as the other two
adapters use it. The unit tier drives v2's own `msc_test` binary; the engine tier drives a
real Apache httpd with `mod_security2.so`.

**Assumptions.**

- Python through `uv`; no new dependency (`subprocess`, `http.client`, `http.server` and
  `socket` are stdlib).
- The engine under test is whatever three variables point at: `MODSECURITY2_HTTPD` (an
  `httpd`/`apache2` binary), `MODSECURITY2_MODULE` (`mod_security2.so`) and
  `MODSECURITY2_MSC_TEST` (`tests/msc_test` from `make check`). Without them the
  conformance tests skip, as the v3 adapter does without `MODSECURITY_LIB`.
- Rows naming ModSecurity v2 stop being predictions: some of the 10 rows will turn out
  obsolete and some unlisted files will fail. Each is classified per `AGENTS.md` before a
  row is written.

## 2. Drivers considered

| Driver | Verdict |
|---|---|
| `tests/msc_test` (`-t tfn\|op -n NAME -p PARAM -r RC`, input on stdin) | **Unit tier.** `-p` is decoded by `unescape_inplace` (`\xNN`), stdin is read raw, so unit byte strings survive; v2's `tests/run-unit-tests.pl.in` drives it the same way. `op` returns only the return code, so `re_groups` cases cannot be observed here (§5). |
| `standalone/api.h` (`modsecInit`, `modsecProcessRequest`, … through ctypes) | **Rejected.** Does not link on `v2/master` (fix `afed19a8` "provide ap_map_http_request_error for the standalone build" is unmerged on `v2/issue-3451-standalone-link`); it emulates Apache, and the nginx connector that used it is being removed. |
| Real httpd + `mod_security2.so` | **Engine tier.** How v2 is deployed; v2's own `tests/run-regression-tests.pl.in` and `tests/regression/server_root/conf/` already generate a conf, start Apache, send a request and match the logs. |

## 3. Shape

```
adapters/modsecurity2/
  README.md
  httpd.py            # conf generation, start/stop httpd -X, stub backend
  engine_tier.py      # profile -> stage results (debug log + HTTP response)
  unit_tier.py        # msc_test for tfn/op; httpd for re_groups cases
  test_conformance.py # same gating as adapters/libmodsecurity/test_conformance.py
  test_adapter.py     # self-tests: debug-log parser, msc_test escaping, conf text
```

`data.py` and `gaps.py` from `adapters/libmodsecurity` are engine-neutral (the profile
loader and `load_gaps(path, engine)`); the v2 adapter imports them from that directory
rather than copying them. Moving them to a shared package is left until a third Python
adapter needs them.

## 4. Engine tier

**Per profile** a fresh temporary `ServerRoot` holding:

- `httpd.conf`: `ServerName localhost`, `Listen 127.0.0.1:<free port>`, `LoadModule` for
  `mpm_event`, `authz_core`, `unique_id` (v2 refuses every request without it: "ModSecurity
  requires mod_unique_id to be installed."), `remoteip`, `proxy`, `proxy_http` and
  `security2`,
  `ErrorLog`, `PidFile`, `SecDataDir` and
  `SecTmpDir` in the root, `SecDebugLog debug.log`, `SecDebugLogLevel 4`, then `Include`
  of the profile's rules file;
- the profile's `files:` at their relative paths, so `Include` and `@pmFromFile` resolve;
- `ProxyPass / http://127.0.0.1:<stub port>/` for every request.

httpd runs as `httpd -X -f <root>/httpd.conf` (one process, foreground, so the debug log is
written in request order) and is stopped after the profile. A fresh process and data dir
per profile keeps `initcol` collections from leaking between profiles.

**Stub backend.** A `http.server` thread owned by the adapter answers every proxied
request with the stage's `response` (status, headers, body) when the stage has one and
`200` with an empty body otherwise, so phases 3–5 run.

**Client address.** Profiles that set `remote_addr` (`ipmatch.yaml`,
`remote-addr-unique-id.yaml`, `persistent-collections.yaml`) cannot be reproduced over a
loopback socket, so the conf loads `mod_remoteip` with `RemoteIPHeader
X-Seclang-Remote-Addr` and `RemoteIPInternalProxy 127.0.0.1`, and the adapter sends that
header when `remote_addr` is not `127.0.0.1`. Probed on 2.9.15: `REMOTE_ADDR` is the
header's address in phases 1 and 2 (IPv4 and IPv6, `@ipMatch` matches), and the header is
removed before rules see `REQUEST_HEADERS`.

**Per stage** the adapter records the debug-log and error-log offsets, sends the request
raw over a socket (the method, URI and headers exactly as the profile gives them), reads
the response, then reads the new log segments.

- *Triggered rules*: the `[id "N"]` of every debug-log line in the segment that starts
  with one of the match messages below. Probed on 2.9.15 (Debian bookworm, Apache 2.4):
  v2 writes exactly one such line per matched rule, `nolog` included, and for a chain only
  when every member matched (the line carries the chain head's id). A chain that fails, a
  rule that does not match and a rule skipped by `skipAfter` write none.

  | Outcome | Debug-log message (level) |
  |---|---|
  | pass / block resolved to pass, `SecAction` | `Warning. … [id "N"]` (2 with `log`, 4 with `nolog`) |
  | deny | `Access denied with code 403 (phase 2). … [id "N"]` (1) |
  | drop | `Access denied with connection close (phase 1). … [id "N"]` (4) |
  | redirect | `Access denied with redirection to URL using status 302 (phase 1). … [id "N"]` (4) |
  | allow | `Access allowed (phase 1). … [id "N"]` (4) |

  `Recipe: Invoking rule …` / `Rule returned 0|1.` are also written but are not needed:
  chain members are invoked without an id, so the match messages are simpler to read.
- *Interruption*: the `Access denied …` line gives the action and `rule_id`; the HTTP
  response gives the status (`Location` for redirect); `drop` closes the connection with
  no response bytes.
- *log_contains*: substring search over the error-log segment, where v2 writes its
  `ModSecurity:` messages.

**Apache in front.** httpd may reject or rewrite a request before ModSecurity sees it
(malformed request line, unknown method, URI normalisation). Such a failure is "Apache,
not engine": it gets a comment in the profile run or a skip, never a known-gaps row
claiming a v2 divergence.

## 5. Unit tier

- **Transformations**: `msc_test -t tfn -n NAME -p <expected output, escaped>` with the
  input on stdin; exit status 0 is a pass. The adapter escapes every byte outside
  0x21–0x7e and every `\` as `\xNN` (a literal `\x41` in a parameter would otherwise be
  decoded). On failure the `Output:` line is reported.
- **Operators**: `msc_test -t op -n NAME -p <param, escaped> -r <0|1>`.
- **`re_groups`** (12 cases in `rx.json` and `rx-pcre-extra.json`): through httpd with
  one rule over `REQUEST_BODY` plus one `TX:i` rule per group, as the v3 adapter does,
  reusing the engine-tier code.

## 6. Known gaps

The gating table of the other adapters applies to rows whose Engine cell names
`ModSecurity v2`. `compat/known-gaps.md`'s introduction, `AGENTS.md` (the "Rows naming
only ModSecurity v2 are predictions" sentence) and `README.md` change with the first
green run.

## 7. CI

The engine runs in a container, locally and in CI, from `adapters/modsecurity2/Dockerfile`:
Debian bookworm, the apt packages of v2's own `.github/workflows/ci.yml` (PCRE2 is the
default; Lua off), `v2.9.15` cloned with `--recurse-submodules` (libinjection is a
submodule), `make install` for `mod_security2.so`, `make -C tests msc_test`, and `uv`. The
image sets the three variables; the repository is mounted at `/repo`:

```sh
docker build -t seclang-modsecurity2 adapters/modsecurity2
docker run --rm -v "$PWD":/repo seclang-modsecurity2 \
  uv run python -m unittest discover -s adapters/modsecurity2
```

The whole adapter runs inside the container because both tiers start processes and read
log files there. A `modsecurity2-adapter` job in `.github/workflows/validate.yml` builds the
same image (layer cache keyed on the Dockerfile) and runs the same command, so local and
CI runs cannot drift. Generated configs use `-f` with a full conf, never Debian's
`envvars`/`apache2ctl` layout.

## 8. Open points

- Whether the differential run (`differential.py`) gets a v2 leg; not in the first cut.
