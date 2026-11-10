package coraza

import (
	"os"
	"path/filepath"
	"testing"
)

const sampleGaps = "# Known conformance gaps\n\n| Test | Engine | Behaviour today | Decided in |\n|---|---|---|---|\n" +
	"| `tests/engine/a.yaml` | Coraza | one | ADR-1 |\n" +
	"| `tests/engine/b.yaml`, `tests/engine/c.yaml` | libmodsecurity v3, Coraza | two | ADR-2 |\n" +
	"| `tests/engine/d.yaml` | ModSecurity v2 | three | ADR-3 |\n" +
	"| `tests/engine/e.yaml` | Coraza (`some.build.tag` build only) | four | ADR-4 |\n"

func TestLoadGaps(t *testing.T) {
	p := filepath.Join(t.TempDir(), "known-gaps.md")
	if err := os.WriteFile(p, []byte(sampleGaps), 0o644); err != nil {
		t.Fatal(err)
	}
	gaps, err := LoadGaps(p, "coraza")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"tests/engine/a.yaml", "tests/engine/b.yaml", "tests/engine/c.yaml", "tests/engine/e.yaml"} {
		if _, ok := gaps[want]; !ok {
			t.Errorf("missing %s", want)
		}
	}
	if _, ok := gaps["tests/engine/d.yaml"]; ok {
		t.Error("v2-only row must not count for coraza")
	}
	if gaps["tests/engine/b.yaml"] != "two" {
		t.Errorf("reason = %q", gaps["tests/engine/b.yaml"])
	}
}

func TestObsoleteRowWarnsOnlyWhenAsked(t *testing.T) {
	t.Setenv(ObsoleteEnv, "")
	if _, fatal := ObsoleteRow("tests/engine/a.yaml", "one"); !fatal {
		t.Fatal("obsolete row must fail by default")
	}
	t.Setenv(ObsoleteEnv, "warn")
	if msg, fatal := ObsoleteRow("tests/engine/a.yaml", "one"); fatal || msg == "" {
		t.Fatalf("warn mode: fatal=%v msg=%q", fatal, msg)
	}
}
