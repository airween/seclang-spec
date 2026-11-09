"""Apache httpd with mod_security2, one process per rule set, and the stub backend it proxies to."""
from __future__ import annotations

import os
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# data, gaps, engine_tier and unit_tier are engine-neutral and shared with the v3 adapter.
# Inserted right after this directory so no installed module of the same name can shadow them.
sys.path.insert(1, str(Path(__file__).resolve().parents[1] / "libmodsecurity"))

from data import Response  # noqa: E402

ENV_HTTPD = "MODSECURITY2_HTTPD"
ENV_MODULE = "MODSECURITY2_MODULE"
REMOTE_ADDR_HEADER = "X-Seclang-Remote-Addr"
_MODULES_DIR = "/usr/lib/apache2/modules"
_START_TIMEOUT = 10.0


class StartError(Exception):
    pass


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def write_root(root: Path, profile_rules: str | bytes, files: dict[str, str], backend_port: int) -> tuple[Path, int]:
    """Write files:, rules.conf and httpd.conf under root; return (conf path, listen port).

    Rules given as bytes are written verbatim (unit-tier byte strings); text is UTF-8.
    The debug-log directives come after the rules so they override any the profile sets.
    """
    for name, content in files.items():
        p = root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    for d in ("data", "tmp", "htdocs"):
        (root / d).mkdir(exist_ok=True)
    rules = profile_rules if isinstance(profile_rules, bytes) else profile_rules.encode("utf-8")
    (root / "rules.conf").write_bytes(rules + b"\n")
    module = os.environ.get(ENV_MODULE, f"{_MODULES_DIR}/mod_security2.so")
    mods = "".join(f"LoadModule {m}_module {_MODULES_DIR}/mod_{m}.so\n"
                   for m in ("mpm_event", "authz_core", "unique_id", "remoteip", "proxy", "proxy_http"))
    port = free_port()
    conf = root / "httpd.conf"
    conf.write_text(
        f"ServerRoot {root}\nServerName localhost\nListen 127.0.0.1:{port}\n{mods}"
        f"LoadModule security2_module {module}\n"
        f"PidFile {root}/httpd.pid\nErrorLog {root}/error.log\nDocumentRoot {root}/htdocs\n"
        f"RemoteIPHeader {REMOTE_ADDR_HEADER}\nRemoteIPInternalProxy 127.0.0.1\n"
        f"ProxyPass / http://127.0.0.1:{backend_port}/\n"
        f"SecDataDir {root}/data\nSecTmpDir {root}/tmp\n"
        f"Include {root}/rules.conf\n"
        f"SecDebugLog {root}/debug.log\nSecDebugLogLevel 4\n")
    return conf, port


def configtest(conf: Path) -> str | None:
    """None when httpd accepts the configuration, else its complaint."""
    r = subprocess.run([os.environ[ENV_HTTPD], "-t", "-f", str(conf)], capture_output=True, text=True)
    return None if r.returncode == 0 else (r.stderr or r.stdout).strip()


class Httpd:
    """`httpd -X` (one process, so the debug log is in request order) for the life of the block."""

    def __init__(self, conf: Path, port: int):
        self.conf, self.port = conf, port
        self.proc: subprocess.Popen | None = None

    def __enter__(self) -> Httpd:
        self.proc = subprocess.Popen([os.environ[ENV_HTTPD], "-X", "-f", str(self.conf)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        deadline = time.monotonic() + _START_TIMEOUT
        while time.monotonic() < deadline:
            if self.proc.poll() is not None:
                err = self.proc.stderr.read().strip()
                self._stop()
                raise StartError(f"httpd exited {self.proc.returncode}: {err}{self._error_log_tail()}")
            try:
                socket.create_connection(("127.0.0.1", self.port), timeout=0.2).close()
                return self
            except OSError:
                time.sleep(0.05)
        self._stop()
        raise StartError(f"httpd did not listen on {self.port} within {_START_TIMEOUT}s{self._error_log_tail()}")

    def __exit__(self, *exc) -> None:
        self._stop()

    def _stop(self) -> None:
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self.proc and self.proc.stderr:
            self.proc.stderr.close()

    def _error_log_tail(self) -> str:
        log = self.conf.parent / "error.log"
        return "; error.log: " + " | ".join(log.read_text(errors="replace").splitlines()[-5:]) if log.exists() else ""


class _Handler(BaseHTTPRequestHandler):
    def _answer(self) -> None:
        n = int(self.headers.get("Content-Length") or 0)
        if n:
            self.rfile.read(n)
        r: Response = self.server.response or Response()  # type: ignore[attr-defined]
        body = r.data.encode("utf-8")  # engine-tier data is UTF-8 text
        self.send_response(r.status)
        for k, v in r.headers.items():
            self.send_header(k, v)
        if not any(k.lower() == "content-length" for k in r.headers):
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    do_GET = do_POST = do_PUT = do_DELETE = do_HEAD = do_OPTIONS = do_PATCH = _answer

    def log_message(self, *args) -> None:
        pass


class Backend:
    """The origin server httpd proxies to; answers every request with the current response."""

    def __init__(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        self.server.response = None  # type: ignore[attr-defined]
        self.port: int = self.server.server_address[1]

    def respond(self, r: Response | None) -> None:
        self.server.response = r  # type: ignore[attr-defined]

    def __enter__(self) -> Backend:
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return self

    def __exit__(self, *exc) -> None:
        self.server.shutdown()
        self.server.server_close()
