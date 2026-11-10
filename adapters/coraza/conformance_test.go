package coraza

import (
	"fmt"
	"path/filepath"
	"sort"
	"testing"

	"github.com/corazawaf/coraza/v3"
)

// implemented lists the Extended feature anchors Coraza 3.8.1 implements; profiles whose
// requires: names anything else are skipped.
var implemented = map[string]bool{"04-directives.md#secrequestbodyinmemorylimit": true}

func needsUnimplemented(p Profile) (string, bool) {
	for _, r := range p.Requires {
		if !implemented[r] {
			return r, true
		}
	}
	return "", false
}

// runProfile returns every mismatch of every stage, prefixed with its location.
func runProfile(t *testing.T, p Profile) []string {
	t.Helper()
	expectError := false
	for _, tc := range p.Tests {
		for _, st := range tc.Stages {
			if st.Stage.Output.ExpectError {
				expectError = true
			}
		}
	}
	waf, log, err := BuildWAF(p, t.TempDir())
	if expectError {
		if err == nil {
			return []string{"configuration loaded but expect_error was set"}
		}
		return nil
	}
	if err != nil {
		return []string{"configuration failed to load: " + err.Error()}
	}
	var failures []string
	for _, tc := range p.Tests {
		for i, st := range tc.Stages {
			o := RunStage(waf, log, st.Stage)
			for _, m := range CheckStage(o, st.Stage.Output) {
				failures = append(failures, fmt.Sprintf("%s / stage %d: %s", tc.Title, i+1, m))
			}
		}
	}
	return failures
}

func reportGated(t *testing.T, path string, gaps map[string]string, failures []string) {
	t.Helper()
	reason, expected := gaps[path]
	switch {
	case expected && len(failures) == 0:
		msg, fatal := ObsoleteRow(path, reason)
		if fatal {
			t.Fatal(msg)
		}
		fmt.Println("::warning::" + msg)
	case expected:
		for _, f := range failures {
			t.Log("expected (known gap: " + reason + "): " + f)
		}
	default:
		for _, f := range failures {
			t.Error(f)
		}
	}
}

func TestEngine(t *testing.T) {
	root := RepoRoot()
	gaps, err := LoadGaps(filepath.Join(root, "compat", "known-gaps.md"), "coraza")
	if err != nil {
		t.Fatal(err)
	}
	profiles, err := LoadProfiles(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range profiles {
		p := p
		t.Run(p.Path, func(t *testing.T) {
			if reason, skip := needsUnimplemented(p); skip {
				t.Skip("requires " + reason)
			}
			reportGated(t, p.Path, gaps, runProfile(t, p))
		})
	}
}

// Extended features Coraza 3.8.1 does not implement; their unit files exist for the other
// engines and are skipped here (00-conventions.md: Extended tests are skipped, not failed).
var unsupportedOperators = map[string]bool{"containsWord": true, "verifyCC": true, "verifycpf": true, "verifyssn": true}
var unsupportedTransformations = map[string]bool{"parityEven7bit": true, "parityOdd7bit": true, "parityZero7bit": true, "sqlHexDecode": true}
var unsupportedAnchors = map[string]bool{"06-operators.md#rx-pcre-extensions": true}

func hasControlChars(s string) bool {
	for _, r := range s {
		if r < 0x20 {
			return true
		}
	}
	return false
}

func TestUnit(t *testing.T) {
	root := RepoRoot()
	gaps, err := LoadGaps(filepath.Join(root, "compat", "known-gaps.md"), "coraza")
	if err != nil {
		t.Fatal(err)
	}
	files, err := LoadUnitCases(root)
	if err != nil {
		t.Fatal(err)
	}
	paths := make([]string, 0, len(files))
	for p := range files {
		paths = append(paths, p)
	}
	sort.Strings(paths)
	for _, path := range paths {
		cases := files[path]
		t.Run(path, func(t *testing.T) {
			if len(cases) > 0 && cases[0].Type == "op" && unsupportedOperators[cases[0].Name] {
				t.Skip("operator not implemented by Coraza (Extended)")
			}
			if len(cases) > 0 && cases[0].Type == "tfn" && unsupportedTransformations[cases[0].Name] {
				t.Skip("transformation not implemented by Coraza (Extended)")
			}
			if len(cases) > 0 && unsupportedAnchors[cases[0].Spec] {
				t.Skip("Extended feature not implemented by Coraza: " + cases[0].Spec)
			}
			var failures []string
			wafs := map[string]coraza.WAF{}
			skipped := 0
			for _, c := range cases {
				if hasControlChars(c.Param) {
					skipped++ // a control character cannot be written inside a directive argument
					continue
				}
				key := c.Type + "\x00" + c.Name + "\x00" + c.Param + "\x00" + fmt.Sprint(len(c.ReGroups) > 0)
				waf, ok := wafs[key]
				if !ok {
					var err error
					waf, err = wafFor(c, t.TempDir())
					if err != nil {
						failures = append(failures, fmt.Sprintf("@%s %q: rule failed to load: %v", c.Name, c.Param, err))
						wafs[key] = nil
						continue
					}
					wafs[key] = waf
				}
				if waf == nil {
					continue
				}
				r, err := runUnitWith(waf, c)
				if err != nil {
					failures = append(failures, fmt.Sprintf("%s %q on %q: %v", c.Name, c.Param, c.Input, err))
					continue
				}
				failures = append(failures, CheckUnit(c, r)...)
			}
			if skipped > 0 {
				t.Logf("%d case(s) skipped: parameter contains control characters", skipped)
			}
			reportGated(t, path, gaps, failures)
		})
	}
}
