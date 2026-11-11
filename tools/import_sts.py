"""Import SecRules Test Set JSON into tests/unit as byte strings with spec anchors.

Usage: uv run python tools/import_sts.py <sts-dir> [--dest tests/unit]
Anchors come from the feature headings of spec/06-operators.md and spec/07-transformations.md.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from tools import validate  # noqa: E402

FIELDS = ("input", "output")  # the runner never decodes "param"
# Files whose content is decided by the spec rather than imported (see the section's
# divergence notes); the importer never overwrites them.
HAND_MAINTAINED = {
    ("transformations", "base64Decode"),
    ("operators", "pmFromFile"),  # pmFromFile cases need corpus-internal files
    ("transformations", "cssDecode"),  # one corpus expectation corrected (07-transformations.md#cssdecode)
}
# Individual corpus cases the spec rejects (06-operators.md#validatebyterange: an empty or
# unparsable parameter is a configuration error, not "permit byte 0").
EXCLUDED_CASES = {
    ("validateByteRange", ""), ("validateByteRange", "xxx"),
    ("ipMatch", "10.0.0.0/100"),  # an unparsable entry is a configuration error (ADR-0024)
    ("unconditionalMatch", "TestCase"),  # the operator takes no parameter (06-operators.md#unconditionalmatch)
}

# Transformation cases (no param) the spec leaves unspecified, keyed by input
# (07-transformations.md#hexdecode: a non-hex byte is unspecified; v2/v3 emit digit-arithmetic garbage).
EXCLUDED_INPUTS = {
    ("hexDecode", "01234567890a0z01234567890a"),
    ("hexDecode", "01234567890az"),
}

_ESC = re.compile(r"\\x([a-zA-Z0-9]{2})|\\u([a-zA-Z0-9]{4})")  # as json2bin: any alphanumerics


def to_wire_bytes(s: str) -> str:
    """Model what libmodsecurity's unit runner feeds the engine, as a Latin-1 byte string.

    test/unit/unit_test.cc json2bin() replaces \\x?? and \\u???? (any two or four
    alphanumerics, parsed with sscanf("%x"): leading hex digits, 0 if none) with ONE byte
    each (the \\u value truncated to its low 8 bits) and nothing else; the \\0 \\b \\t \\n \\r
    replacements are commented out. Every other character arrives as the UTF-8 bytes of
    its code point, because the corpus is read by a UTF-8 JSON parser. The result uses one
    code point <= U+00FF per byte (tests/README.md).
    """
    out = []
    pos = 0
    for m in _ESC.finditer(s):
        out.append(s[pos:m.start()].encode("utf-8").decode("latin-1"))
        digits = re.match(r"[0-9a-fA-F]*", m.group(1) or m.group(2)).group(0)  # sscanf("%x") semantics
        value = (int(digits, 16) if digits else 0) & 0xFF
        out.append(chr(value))
        pos = m.end()
    out.append(s[pos:].encode("utf-8").decode("latin-1"))
    return "".join(out)


def to_byte_string(s: str) -> str:
    """Characters above U+00FF become their UTF-8 bytes; used for fields the runner does not decode."""
    return s.encode("utf-8").decode("latin-1") if any(ord(ch) > 0xFF for ch in s) else s


def convert_case(case: dict, anchor: str) -> dict | None:
    if ("resource" in case or (case.get("name"), case.get("param")) in EXCLUDED_CASES
            or (case.get("name"), case.get("input")) in EXCLUDED_INPUTS):
        return None
    out = {}
    for k, v in case.items():
        if isinstance(v, str) and k in FIELDS:
            out[k] = to_wire_bytes(v)
        elif isinstance(v, str) and k == "param":
            out[k] = to_byte_string(v)
        else:
            out[k] = v
    if out.get("type") == "tfn":
        # tests/README.md: ret is 1 when the output differs from the input. The corpus
        # carries the engine's return code, which v2 hardcodes to 1 for some transformations.
        out["ret"] = int(out["output"] != out["input"])
    out["spec"] = anchor
    return out


def main(src: Path, dest: Path, anchors: dict[str, str]) -> dict[str, int]:
    counts = {}
    for tier in ("operators", "transformations"):
        for path in sorted((src / tier).glob("*.json")):
            name = path.stem
            anchor = anchors.get(name) or anchors.get(name.lower())
            if not anchor or (tier, name) in HAND_MAINTAINED:
                continue
            cases = [c for c in (convert_case(dict(c, name=name), anchor) for c in json.loads(path.read_text())) if c]
            if not cases:
                continue
            (dest / tier).mkdir(parents=True, exist_ok=True)
            (dest / tier / f"{name}.json").write_text(json.dumps(cases, indent=1, ensure_ascii=False) + "\n")
            counts[name] = len(cases)
    return counts


def anchors_from_spec(root: Path) -> dict[str, str]:
    """Heading slug (lowercased name) -> anchor, for operators and transformations."""
    out = {}
    for anchor, status in validate.spec_features(root).items():
        file, frag = anchor.split("#")
        if file in ("06-operators.md", "07-transformations.md") and status in ("Core", "Extended"):
            out[frag] = anchor
    return out


if __name__ == "__main__":
    src = Path(sys.argv[1])
    dest = Path(sys.argv[sys.argv.index("--dest") + 1]) if "--dest" in sys.argv else validate.ROOT / "tests" / "unit"
    counts = main(src, dest, anchors_from_spec(validate.ROOT))
    print(f"imported {sum(counts.values())} cases into {len(counts)} files", file=sys.stderr)
