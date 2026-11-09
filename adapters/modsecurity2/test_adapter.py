"""The adapter's own tests: conf text, parsers and escaping always; engine smoke tests when
MODSECURITY2_HTTPD / MODSECURITY2_MSC_TEST are set (the Docker image sets both)."""
import http.client
import os
import tempfile
import time
import unittest
from pathlib import Path

import httpd  # first: puts adapters/libmodsecurity on sys.path
import data
import v2_engine
import v2_unit
from data import Input, Interruption, Output, Profile, Response, Stage, Test, UnitCase

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


def debug_line(level: int, msg: str) -> bytes:
    """One v2.9.15 debug-log line as written by Apache (copied from a probe run)."""
    return (b"[09/Nov/2026:14:39:29.182013 +0000] [localhost/sid#ffff865494a0][rid#ffff863e40a0]"
            b"[/index.html][%d] " % level) + msg.encode()


R = ' [file "/tmp/root/rules.conf"] [line "4"]'


class ParseDebugLogTests(unittest.TestCase):
    def parse(self, *lines: bytes):
        return v2_engine.parse_debug_log(b"\n".join(lines) + b"\n")

    def test_parse_pass_nolog_chain(self):
        self.assertEqual(self.parse(
            debug_line(4, f'Warning. Unconditional match in SecAction.{R} [id "1"]'),
            debug_line(2, f'Warning. String match "y" at ARGS:b.{R} [id "4"] [msg "two"]'),
            debug_line(4, f'Warning. String match "x" at ARGS:a.{R} [id "5"]'),
            debug_line(4, 'Continuing execution after rule id="END".'),
        ), ({1, 4, 5}, None))

    def test_parse_deny(self):
        triggered, disruptive = self.parse(
            debug_line(4, f'Warning. Unconditional match in SecAction.{R} [id "1"]'),
            debug_line(1, f'Access denied with code 403 (phase 2). String match "x" at ARGS:a.{R} [id "7"] [msg "d"]'))
        self.assertEqual((triggered, disruptive), ({1, 7}, (7, "deny", 403)))

    def test_parse_drop_redirect_allow(self):
        self.assertEqual(self.parse(debug_line(
            4, f'Access denied with connection close (phase 1). String match "drop" at ARGS:k.{R} [id "12"]')),
            ({12}, (12, "drop", None)))
        self.assertEqual(self.parse(debug_line(
            4, 'Access denied with redirection to http://example.com/ using status 302 (phase 1). '
               f'String match "redir" at ARGS:k.{R} [id "13"]')),
            ({13}, (13, "redirect", 302)))
        self.assertEqual(self.parse(debug_line(
            4, f'Access allowed (phase 1). String match "allow" at ARGS:k.{R} [id "11"]')),
            ({11}, None))

    def test_parse_allow_phase_and_request(self):
        self.assertEqual(self.parse(
            debug_line(1, f'Access to phase allowed (phase 1). String match "phase" at ARGS_GET:mode.{R} [id "7071"]'),
            debug_line(1, f'Access to request allowed (phase 1). String match "r" at ARGS_GET:mode.{R} [id "7075"]'),
        ), ({7071, 7075}, None))

    def test_parse_status_from_log_line(self):
        # Apache answers 500 for a status it has no reason phrase for (418); v2's line has the code.
        self.assertEqual(self.parse(debug_line(
            1, f'Access denied with code 418 (phase 1). String match "teapot" at ARGS_GET:a.{R} [id "7050"]'))[1],
            (7050, "deny", 418))
        self.assertEqual(self.parse(debug_line(
            1, 'Access denied with redirection to https://example.org/ using status 307 (phase 1). '
               f'String match "go" at ARGS_GET:a.{R} [id "7051"]'))[1],
            (7051, "redirect", 307))

    def test_parse_ignores_recipe_lines(self):
        self.assertEqual(self.parse(
            debug_line(4, f'Recipe: Invoking rule ffff8644ad48;{R} [id "3"].'),
            debug_line(4, "Rule returned 0."),
        ), (set(), None))


class RequestTests(unittest.TestCase):
    def test_request_bytes(self):
        raw = v2_engine.request_bytes(Input(method="POST", uri="/a?b=1", headers={"Content-Type": "x"}, data="é"))
        self.assertTrue(raw.startswith(b"POST /a?b=1 HTTP/1.1\r\n"))
        for h in (b"Host: localhost\r\n", b"Content-Length: 2\r\n", b"Connection: close\r\n", b"Content-Type: x\r\n"):
            self.assertIn(h, raw)
        self.assertTrue(raw.endswith(b"\r\n\r\n\xc3\xa9"))
        self.assertNotIn(httpd.REMOTE_ADDR_HEADER.encode(), raw)

    def test_request_bytes_remote_addr(self):
        raw = v2_engine.request_bytes(Input(remote_addr="2001:db8:1::5"))
        self.assertIn(b"X-Seclang-Remote-Addr: 2001:db8:1::5\r\n", raw)

    def test_request_bytes_no_duplicate_host(self):
        raw = v2_engine.request_bytes(Input(headers={"host": "example.com"}))
        self.assertEqual(raw.lower().count(b"host:"), 1)


LIMIT = b'[client 127.0.0.1:1] ModSecurity: Request body (Content-Length) is larger than the configured limit (10).'
RULE = b'[client 127.0.0.1:1] ModSecurity: Warning. String match "x" at ARGS:a. [id "1"]'


class InterruptionTests(unittest.TestCase):
    def test_body_limit_without_rule(self):
        self.assertEqual(v2_engine.interruption(413, None, LIMIT), Interruption(0, "deny", 413))

    def test_body_limit_with_status_the_backend_would_also_send(self):
        # keyed on v2's own message, not on the status differing from the backend's
        self.assertEqual(v2_engine.interruption(500, None, LIMIT), Interruption(0, "deny", 500))

    def test_no_engine_message_is_not_an_interruption(self):
        self.assertIsNone(v2_engine.interruption(200, None, b""))
        self.assertIsNone(v2_engine.interruption(404, None, b""))

    def test_rule_message_alone_is_not_an_engine_interruption(self):
        # a logged phase-1 rule followed by an Apache 400 (AH10244, `..` in the URI)
        self.assertIsNone(v2_engine.interruption(400, None, RULE))

    def test_rule_interruptions(self):
        self.assertEqual(v2_engine.interruption(None, (12, "drop", None), b""), Interruption(12, "drop", 0))
        self.assertEqual(v2_engine.interruption(302, (13, "redirect", 302), b""), Interruption(13, "redirect", 302))
        self.assertEqual(v2_engine.interruption(500, (7050, "deny", 418), b""), Interruption(7050, "deny", 418))


@needs_httpd
class EngineTests(unittest.TestCase):
    def profile(self, rules: str, uri: str, output: Output) -> Profile:
        return Profile("tests/engine/x.yaml", [], {}, rules, [Test("t", [Stage(Input(uri=uri), None, output)])])

    def test_disruptive_profile_passes(self):
        p = self.profile('SecRuleEngine On\nSecRule ARGS:a "@streq x" "id:7,phase:1,deny,status:403"',
                         "/?a=x", Output(triggered_rules=[7], interruption=Interruption(7, "deny", 403)))
        with httpd.Backend() as b:
            self.assertEqual(v2_engine.run_profile(p, b), [])

    def test_audit_log_per_stage(self):
        rules = 'SecRuleEngine On\nSecRule ARGS:a "@streq 1" "id:5,phase:1,pass,log"'
        stages = [Stage(Input(uri="/?a=1", headers={"X-Probe": "first-probe"}), None, Output(audit_log_contains="first-probe")),
                  Stage(Input(uri="/?a=1", headers={"X-Probe": "second-probe"}), None,
                        Output(audit_log_contains="second-probe", no_audit_log_contains="first-probe"))]
        p = Profile("tests/engine/x.yaml", [], {}, rules, [Test("t", stages)])
        with httpd.Backend() as b:
            self.assertEqual(v2_engine.run_profile(p, b), [])

    def test_apache_rejection_reported(self):
        p = self.profile("SecRuleEngine On", "/%", Output(no_interruption=True))
        with httpd.Backend() as b:
            failures = v2_engine.run_profile(p, b)
        self.assertEqual(len(failures), 1)
        self.assertIn("Apache answered 400 without ModSecurity", failures[0])

    def test_apache_rejection_before_modsecurity_does_not_wait(self):
        # a bad protocol version never reaches v2: no transaction, no logging phase to wait for
        p = Profile("tests/engine/x.yaml", [], {}, "SecRuleEngine On",
                    [Test("t", [Stage(Input(version="HTTP/9"), None, Output(no_interruption=True))])])
        with httpd.Backend() as b:
            t0 = time.monotonic()
            v2_engine.run_profile(p, b)
            self.assertLess(time.monotonic() - t0, 1.5)

    def test_apache_rejection_after_logged_phase1_rule(self):
        p = self.profile('SecRuleEngine On\nSecRule REQUEST_URI "@contains x" "id:1,phase:1,pass,log"',
                         "/x/../../b", Output(triggered_rules=[1], no_interruption=True))
        with httpd.Backend() as b:
            failures = v2_engine.run_profile(p, b)
        self.assertEqual(len(failures), 1)
        self.assertIn("Apache answered 400 without ModSecurity", failures[0])

    def test_expect_error(self):
        p = self.profile("SecFoo bar", "/", Output(expect_error=True))
        with httpd.Backend() as b:
            self.assertEqual(v2_engine.run_profile(p, b), [])


needs_msc_test = unittest.skipUnless(os.environ.get(v2_unit.ENV_MSC_TEST), f"{v2_unit.ENV_MSC_TEST} not set")


def tfn(name: str, inp: str, out: str) -> UnitCase:
    return UnitCase("tfn", name, None, inp, out, 1, "", [])


class MscTestArgsTests(unittest.TestCase):
    def test_msc_escape(self):
        self.assertEqual(v2_unit.msc_escape("a\\b\x00\xff ~"), "a\\x5cb\\x00\\xff\\x20~")

    def test_msc_test_args_tfn_op(self):
        self.assertEqual(v2_unit.msc_test_args(tfn("lowercase", "AB\x01", "ab\x01")),
                         ["-t", "tfn", "-n", "lowercase", "-p", "ab\\x01"])
        op = UnitCase("op", "rx", None, "x", "", 0, "", [])
        self.assertEqual(v2_unit.msc_test_args(op)[-4:], ["-p", "", "-r", "0"])


@needs_msc_test
class MscTestTests(unittest.TestCase):
    def test_msc_test_runs(self):
        with httpd.Backend() as b:
            self.assertEqual(v2_unit.run_unit_file([tfn("lowercase", "AB\x01", "ab\x01")], b), [])
            failures = v2_unit.run_unit_file([tfn("lowercase", "AB\x01", "XYZ")], b)
        self.assertEqual(len(failures), 1)
        self.assertIn("Output:", failures[0])


@needs_httpd
class ReGroupsTests(unittest.TestCase):
    def test_re_groups_case(self):
        cases = data.load_unit_cases(data.repo_root())["tests/unit/operators/rx.json"]
        case = next(c for c in cases if c.re_groups)
        with httpd.Backend() as b:
            self.assertEqual(v2_unit.run_unit_file([case], b), [])

    def test_re_groups_rule_that_fails_to_load_is_reported(self):
        case = UnitCase("op", "rx", 'a"b', "a", "", 1, "", ["a"])
        with httpd.Backend() as b:
            failures = v2_unit.run_unit_file([case], b)
        self.assertEqual(len(failures), 1)
        self.assertIn("rule failed to load", failures[0])

    @needs_msc_test
    def test_re_groups_control_char_param_uses_msc_test(self):
        # a control character cannot be written inside a directive argument: match result only
        with httpd.Backend() as b:
            self.assertEqual(v2_unit.run_unit_file(
                [UnitCase("op", "rx", "abc\ndef", "abc\ndef", "", 1, "", ["abc\ndef"])], b), [])
            failures = v2_unit.run_unit_file(
                [UnitCase("op", "rx", "abc\ndef", "xyz", "", 1, "", ["abc\ndef"])], b)
        self.assertEqual(len(failures), 1)
        self.assertIn("msc_test exit 1", failures[0])


if __name__ == "__main__":
    unittest.main()
