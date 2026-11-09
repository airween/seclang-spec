package coraza

import (
	"strings"
	"testing"
)

func TestRunStageDenies(t *testing.T) {
	p := Profile{Rules: "SecRuleEngine On\nSecRule ARGS_GET:a \"@streq 1\" \"id:1,phase:1,deny,status:403,log,msg:'probe'\"\n"}
	waf, log, err := BuildWAF(p, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	o := RunStage(waf, log, Stage{Input: Input{URI: "/?a=1"}})
	if !o.Triggered[1] || o.Interruption == nil || o.Interruption.Status != 403 || o.Interruption.Action != "deny" {
		t.Fatalf("observed %+v", o)
	}
	if len(o.Log) == 0 || !strings.Contains(o.Log[0], "probe") {
		t.Fatalf("log = %v", o.Log)
	}
}

func TestCheckStageReportsMismatch(t *testing.T) {
	o := Observed{Triggered: map[int]bool{2: true}}
	msgs := CheckStage(o, Output{TriggeredRules: []int{1}, NonTriggeredRules: []int{2}, NoInterruption: true})
	if len(msgs) != 2 {
		t.Fatalf("want 2 mismatches, got %v", msgs)
	}
	if msgs := CheckStage(o, Output{TriggeredRules: []int{2}, NoInterruption: true}); len(msgs) != 0 {
		t.Fatalf("unexpected mismatches %v", msgs)
	}
}

func TestRunStageDeliversUTF8Data(t *testing.T) {
	// Engine-tier data is ordinary text (UTF-8), not a byte string.
	p := Profile{Rules: "SecRuleEngine On\nSecRequestBodyAccess On\nSecRule ARGS_POST:p \"@streq \u20ac\" \"id:1,phase:2,pass\"\n"}
	waf, log, err := BuildWAF(p, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	o := RunStage(waf, log, Stage{Input: Input{Method: "POST", URI: "/", Headers: map[string]string{"Content-Type": "application/x-www-form-urlencoded"}, Data: "p=\u20ac"}})
	if o.Panic != "" || !o.Triggered[1] {
		t.Fatalf("observed %+v", o)
	}
}

func TestBuildWAFWritesFiles(t *testing.T) {
	p := Profile{Files: map[string]string{"inc/x.conf": "SecRule ARGS_GET:a \"@streq 1\" \"id:3,phase:1,pass\"\n"},
		Rules: "SecRuleEngine On\nInclude inc/x.conf\n"}
	waf, log, err := BuildWAF(p, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if o := RunStage(waf, log, Stage{Input: Input{URI: "/?a=1"}}); !o.Triggered[3] {
		t.Fatalf("included rule did not fire: %+v", o)
	}
}

func TestRunStageRecoversFromEnginePanic(t *testing.T) {
	// Coraza 3.8.1 dereferences a nil macro on `setvar:!tx.x` (internal/actions/setvar.go,
	// Evaluate). If upstream fixes it this test still passes: either a panic is reported or
	// the rule simply matches.
	p := Profile{Rules: "SecRuleEngine On\nSecAction \"id:1,phase:1,pass,nolog,setvar:!tx.x\"\n"}
	waf, log, err := BuildWAF(p, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	o := RunStage(waf, log, Stage{Input: Input{URI: "/"}})
	if o.Panic == "" && !o.Triggered[1] {
		t.Fatalf("neither a panic nor a match: %+v", o)
	}
	if o.Panic != "" && len(CheckStage(o, Output{TriggeredRules: []int{1}})) != 1 {
		t.Fatal("a panic must be reported as exactly one mismatch")
	}
}

func TestRunStageCapturesAuditLog(t *testing.T) {
	out := Output{AuditLogContains: "x", NoAuditLogContains: "y"}
	p := Profile{
		Rules: "SecRuleEngine On\nSecRule ARGS_GET:a \"@streq 1\" \"id:5,phase:1,pass,log\"\n",
		Tests: []Test{{Stages: []struct {
			Stage Stage `yaml:"stage"`
		}{{Stage: Stage{Output: out}}}}},
	}
	waf, log, err := BuildWAF(p, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	for _, v := range []string{"first-probe", "second-probe"} {
		o := RunStage(waf, log, Stage{Input: Input{URI: "/?a=1", Headers: map[string]string{"X-Probe": v}}})
		if !strings.Contains(o.Audit, v) || (v == "second-probe" && strings.Contains(o.Audit, "first-probe")) {
			t.Fatalf("audit for %s = %q", v, o.Audit)
		}
		if msgs := CheckStage(o, Output{AuditLogContains: v, NoAuditLogContains: "absent-value"}); len(msgs) != 0 {
			t.Fatal(msgs)
		}
	}
}
