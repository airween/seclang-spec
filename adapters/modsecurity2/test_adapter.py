"""The adapter's own tests: conf text, parsers and escaping always; engine smoke tests when
MODSECURITY2_HTTPD / MODSECURITY2_MSC_TEST are set (the Docker image sets both)."""
import http.client
import os
import tempfile
import unittest
from pathlib import Path

import httpd  # first: puts adapters/libmodsecurity on sys.path
from data import Response

needs_httpd = unittest.skipUnless(os.environ.get(httpd.ENV_HTTPD), f"{httpd.ENV_HTTPD} not set")


def get(port: int, path: str = "/") -> tuple[int, dict[str, str], bytes]:
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
    try:
        c.request("GET", path)
        r = c.getresponse()
        return r.status, dict(r.getheaders()), r.read()
    finally:
        c.close()


class HttpdConfTests(unittest.TestCase):
    def test_conf_has_required_modules(self):
        with tempfile.TemporaryDirectory() as d:
            conf, _ = httpd.write_root(Path(d), "SecRuleEngine On", {}, 9)
            text = conf.read_text()
        for mod in ("mpm_event", "authz_core", "unique_id", "remoteip", "proxy", "proxy_http", "security2"):
            self.assertIn(f"LoadModule {mod}_module ", text)
        self.assertIn("ServerName localhost", text)
        self.assertIn("RemoteIPHeader X-Seclang-Remote-Addr", text)
        self.assertIn("ProxyPass / http://127.0.0.1:9/", text)
        self.assertLess(text.index("rules.conf"), text.index("SecDebugLogLevel 4"))

    def test_files_written_relative(self):
        with tempfile.TemporaryDirectory() as d:
            httpd.write_root(Path(d), "", {"sub/x.data": "a\n"}, 9)
            self.assertEqual((Path(d) / "sub" / "x.data").read_text(), "a\n")


class BackendTests(unittest.TestCase):
    def test_backend_serves_response(self):
        with httpd.Backend() as b:
            b.respond(Response(201, {"X-A": "b"}, "hi"))
            status, headers, body = get(b.port)
            self.assertEqual((status, headers.get("X-A"), body), (201, "b", b"hi"))
            b.respond(None)
            status, _, body = get(b.port)
            self.assertEqual((status, body), (200, b""))


@needs_httpd
class HttpdTests(unittest.TestCase):
    def test_httpd_start_and_proxy(self):
        with tempfile.TemporaryDirectory() as d, httpd.Backend() as b:
            b.respond(Response(202, {}, "ok"))
            conf, port = httpd.write_root(Path(d), "SecRuleEngine On", {}, b.port)
            with httpd.Httpd(conf, port):
                status, _, body = get(port)
                self.assertEqual((status, body), (202, b"ok"))

    def test_httpd_bad_rules(self):
        with tempfile.TemporaryDirectory() as d:
            conf, _ = httpd.write_root(Path(d), "SecFoo bar", {}, 9)
            self.assertIsNotNone(httpd.configtest(conf))

    def test_httpd_start_failure_raises(self):
        with tempfile.TemporaryDirectory() as d:
            conf, port = httpd.write_root(Path(d), "SecFoo bar", {}, 9)
            with self.assertRaises(httpd.StartError):
                with httpd.Httpd(conf, port):
                    pass


if __name__ == "__main__":
    unittest.main()
