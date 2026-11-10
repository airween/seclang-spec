// Package coraza runs the seclang-spec conformance data against Coraza through its
// public API. See README.md in this directory.
package coraza

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"
)

var gapPathRe = regexp.MustCompile("`(tests/[^`]+)`")

// ObsoleteEnv set to "warn" turns an obsolete known-gaps row into a GitHub warning instead of
// a failure: an engine's own CI (action.yml) must not fail because it fixed a known gap.
const ObsoleteEnv = "SECLANG_OBSOLETE_GAPS"

// ObsoleteRow is the message for a row whose file now passes, and whether it fails the run.
func ObsoleteRow(path, reason string) (msg string, fatal bool) {
	msg = fmt.Sprintf("known-gaps row is obsolete: remove the row for %s (%s)", path, reason)
	return msg, os.Getenv(ObsoleteEnv) != "warn"
}

// LoadGaps reads compat/known-gaps.md and returns, for rows whose Engine cell names
// `engine` (case-insensitive substring), the test paths of the first cell mapped to the
// "Behaviour today" cell. A cell may list several backticked paths.
func LoadGaps(path, engine string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	out := map[string]string{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if !strings.HasPrefix(line, "| `tests/") {
			continue
		}
		cells := strings.Split(strings.Trim(line, "| "), " | ")
		if len(cells) < 3 || !strings.Contains(strings.ToLower(cells[1]), strings.ToLower(engine)) {
			continue
		}
		for _, m := range gapPathRe.FindAllStringSubmatch(cells[0], -1) {
			out[m[1]] = strings.TrimSpace(cells[2])
		}
	}
	return out, sc.Err()
}
