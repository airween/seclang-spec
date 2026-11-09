"""Engine-tier driver: one rules set per profile, one transaction per stage.

Matched rules (including nolog ones) are read from the engine debug log at level 4; the
intervention from msc_intervention plus the "(disruptive) action" debug line.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from data import Interruption, Output, Profile, Stage
from mscapi import ModSecurity, RulesSet

# The URI field may contain "] [N] "; the greedy match takes the LAST "] [level] " of the
# line, which only a message text of that exact shape could spoof.
AUDIT_LOG = "audit.log"


def uses_audit_log(profile: Profile) -> bool:
    return any(st.output.audit_log_contains or st.output.no_audit_log_contains
               for t in profile.tests for st in t.stages)


def audit_directives(path: Path) -> str:
    """Appended after a profile's rules when it asserts on the audit log (tests/README.md)."""
    return ("\nSecAuditEngine On\nSecAuditLogParts ABCFHZ\nSecAuditLogType Serial\n"
            f"SecAuditLogFormat Native\nSecAuditLog {path}\n")


_LINE = re.compile(rb"^\[[^\]]*\] \[.*\] \[(\d+)\] (.*)$")
_BLOCK = re.compile(rb"^\(Rule: (\d+)\) ")
# Disruptive action names as v3 prints them (lower-cased; v3.0.17 misspells redirect).
# "block" is resolved against the intervention in run_stage.
_ACTIONS = {b"deny": "deny", b"drop": "drop", b"redirect": "redirect", b"redirert": "redirect", b"block": "block"}


def parse_debug_log(data: bytes) -> tuple[set[int], tuple[int, str] | None]:
    """Triggered rule ids and the (rule id, action) of the disruptive action, if any.

    A "(Rule: N)" line with N != 0 opens a block; "(Rule: 0)" is a chain member and keeps
    the block open, so its "Rule returned" decides the chain; "Executing unconditional
    rule" counts as a match. A block is triggered when it is still matched at the next
    block or at the end.
    """
    triggered: set[int] = set()
    disruptive = None
    current, matched = None, False
    for line in data.splitlines():
        m = _LINE.match(line)
        if not m:
            continue
        text = m.group(2)
        b = _BLOCK.match(text)
        if b:
            rid = int(b.group(1))
            if rid:
                if current is not None and matched:
                    triggered.add(current)
                current, matched = rid, b"Executing unconditional rule" in text
        elif text == b"Rule returned 1.":
            matched = True
        elif text == b"Rule returned 0.":
            matched = False
        elif text.startswith(b"Running (disruptive)") and current is not None:
            name = text.rsplit(b"action: ", 1)[-1].rstrip(b".").lower()
            if name in _ACTIONS:
                disruptive = (current, _ACTIONS[name])
    if current is not None and matched:
        triggered.add(current)
    return triggered, disruptive


@dataclass
class Observed:
    triggered: set[int]
    interruption: Interruption | None
    log: str
    audit: str = ""  # the transaction's audit log entry, when the profile asserts on it


def build_rules(ms: ModSecurity, profile: Profile, workdir: Path) -> tuple[RulesSet, Path]:
    """Write files: and rules.conf under workdir and load it; raises LoadError.

    The debug-log directives are appended so they override any the profile sets, and the
    audit-log ones when a stage asserts on the audit log (tests/README.md).
    """
    for name, content in profile.files.items():
        p = workdir / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    debug = workdir / "debug.log"
    conf = workdir / "rules.conf"
    extra = f"\nSecDebugLog {debug}\nSecDebugLogLevel 4\n"
    if uses_audit_log(profile):
        extra += audit_directives(workdir / AUDIT_LOG)
    conf.write_text(profile.rules + extra)
    return ms.rules_from_file(str(conf)), debug


def run_stage(ms: ModSecurity, rules: RulesSet, debug_path: Path, stage: Stage) -> Observed:
    start = debug_path.stat().st_size if debug_path.exists() else 0
    audit_path = debug_path.parent / AUDIT_LOG
    audit_start = audit_path.stat().st_size if audit_path.exists() else 0
    tx = ms.transaction(rules)
    it = None
    try:
        i = stage.input
        tx.connection(i.remote_addr, 12345, "127.0.0.1", 80)
        tx.uri(i.uri, i.method, i.version.removeprefix("HTTP/"))
        for k, v in i.headers.items():
            tx.request_header(k, v)
        if not any(k.lower() == "host" for k in i.headers):
            tx.request_header("Host", "localhost")
        tx.process_request_headers()
        it = tx.intervention()
        if it is None:
            if i.data:
                tx.append_request_body(i.data.encode("utf-8"))  # engine-tier data is UTF-8 text
            tx.process_request_body()
            it = tx.intervention()
        if it is None and stage.response is not None:
            r = stage.response
            for k, v in r.headers.items():
                tx.response_header(k, v)
            tx.process_response_headers(r.status, "HTTP 1.1")
            it = tx.intervention()
            if it is None:
                if r.data:
                    tx.append_response_body(r.data.encode("utf-8"))
                tx.process_response_body()
                it = tx.intervention()
        tx.process_logging()
        it = it or tx.intervention()
        log = list(ms.log)
    finally:
        tx.close()
    segment = debug_path.read_bytes()[start:] if debug_path.exists() else b""
    triggered, disruptive = parse_debug_log(segment)
    interruption = None
    if it is not None:
        rule_id, action = disruptive if disruptive else (0, "deny")  # no rule block: a body limit
        if action == "block":  # the default action's disruptive action; v3 prints no second line
            action = "redirect" if it["url"] else "deny"
        interruption = Interruption(rule_id, action, it["status"])
        if it["log"]:
            log.append(it["log"])  # v3 puts a denying rule's message here, not in the callback
    audit = audit_path.read_bytes()[audit_start:] if audit_path.exists() else b""
    return Observed(triggered, interruption, b"\n".join(log).decode("utf-8", "replace"),
                    audit.decode("utf-8", "replace"))


def check_stage(o: Observed, want: Output) -> list[str]:
    """Every mismatch in words; empty when the stage passes."""
    msgs = []
    for rid in want.triggered_rules:
        if rid not in o.triggered:
            msgs.append(f"rule {rid} expected to trigger; triggered={sorted(o.triggered)}")
    for rid in want.non_triggered_rules:
        if rid in o.triggered:
            msgs.append(f"rule {rid} expected not to trigger")
    if want.no_interruption and o.interruption is not None:
        msgs.append(f"unexpected interruption: rule {o.interruption.rule_id} {o.interruption.action} {o.interruption.status}")
    if want.interruption is not None:
        w = want.interruption
        if o.interruption is None:
            msgs.append(f"expected interruption by rule {w.rule_id} ({w.action}), none observed")
        else:
            if o.interruption.rule_id != w.rule_id:
                msgs.append(f"interruption by rule {o.interruption.rule_id}, expected {w.rule_id}")
            if o.interruption.action != w.action:
                msgs.append(f"interruption action {o.interruption.action!r}, expected {w.action!r}")
            if w.status and o.interruption.status != w.status:
                msgs.append(f"interruption status {o.interruption.status}, expected {w.status}")
    if want.log_contains and want.log_contains not in o.log:
        msgs.append(f"log does not contain {want.log_contains!r}")
    if want.no_log_contains and want.no_log_contains in o.log:
        msgs.append(f"log contains {want.no_log_contains!r}")
    if want.audit_log_contains and want.audit_log_contains not in o.audit:
        msgs.append(f"audit log does not contain {want.audit_log_contains!r}")
    if want.no_audit_log_contains and want.no_audit_log_contains in o.audit:
        msgs.append(f"audit log contains {want.no_audit_log_contains!r}")
    return msgs
