package coraza

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// Profile mirrors tests/schema/engine.schema.json.
type Profile struct {
	Meta struct {
		Name        string `yaml:"name"`
		Description string `yaml:"description"`
		Author      string `yaml:"author"`
		Enabled     *bool  `yaml:"enabled"`
	} `yaml:"meta"`
	Spec     string            `yaml:"spec"`
	Requires []string          `yaml:"requires"`
	Files    map[string]string `yaml:"files"`
	Rules    string            `yaml:"rules"`
	Tests    []Test            `yaml:"tests"`
	Path     string            `yaml:"-"` // relative to the repository root
}

type Test struct {
	Title  string `yaml:"test_title"`
	Desc   string `yaml:"desc"`
	Spec   string `yaml:"spec"`
	Stages []struct {
		Stage Stage `yaml:"stage"`
	} `yaml:"stages"`
}

type Stage struct {
	Input    Input     `yaml:"input"`
	Response *Response `yaml:"response"`
	Output   Output    `yaml:"output"`
}

type Input struct {
	Method     string            `yaml:"method"`
	URI        string            `yaml:"uri"`
	Version    string            `yaml:"version"`
	Headers    map[string]string `yaml:"headers"`
	Data       string            `yaml:"data"`
	RemoteAddr string            `yaml:"remote_addr"`
	DestAddr   string            `yaml:"dest_addr"`
	Port       int               `yaml:"port"`
}

type Response struct {
	Status  int               `yaml:"status"`
	Headers map[string]string `yaml:"headers"`
	Data    string            `yaml:"data"`
}

type Interruption struct {
	RuleID int    `yaml:"rule_id"`
	Action string `yaml:"action"`
	Status int    `yaml:"status"`
	Data   string `yaml:"data"`
}

type Output struct {
	TriggeredRules     []int         `yaml:"triggered_rules"`
	NonTriggeredRules  []int         `yaml:"non_triggered_rules"`
	Interruption       *Interruption `yaml:"interruption"`
	NoInterruption     bool          `yaml:"no_interruption"`
	LogContains        string        `yaml:"log_contains"`
	NoLogContains      string        `yaml:"no_log_contains"`
	AuditLogContains   string        `yaml:"audit_log_contains"`
	NoAuditLogContains string        `yaml:"no_audit_log_contains"`
	ExpectError        bool          `yaml:"expect_error"`
}

// UnitCase mirrors tests/schema/unit.schema.json. Strings are byte strings (one code
// point per byte); use latin1() before handing them to the engine.
type UnitCase struct {
	Type     string   `json:"type"`
	Name     string   `json:"name"`
	Param    string   `json:"param"`
	Input    string   `json:"input"`
	Output   string   `json:"output"`
	Ret      int      `json:"ret"`
	Spec     string   `json:"spec"`
	Note     string   `json:"note"`
	ReGroups []string `json:"re_groups"`
	HasParam bool     `json:"-"`
}

// RepoRoot walks up from this source file to the directory that contains tests/.
func RepoRoot() string {
	_, file, _, _ := runtime.Caller(0)
	dir := filepath.Dir(file)
	for i := 0; i < 6; i++ {
		if st, err := os.Stat(filepath.Join(dir, "tests", "schema")); err == nil && st.IsDir() {
			return dir
		}
		dir = filepath.Dir(dir)
	}
	panic("repository root not found above " + file)
}

// LoadProfiles reads every tests/engine/**/*.yaml, strictly (unknown fields are errors).
func LoadProfiles(root string) ([]Profile, error) {
	var out []Profile
	base := filepath.Join(root, "tests", "engine")
	err := filepath.WalkDir(base, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".yaml") {
			return err
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var p Profile
		dec := yaml.NewDecoder(strings.NewReader(string(raw)))
		dec.KnownFields(true)
		if err := dec.Decode(&p); err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		rel, _ := filepath.Rel(root, path)
		p.Path = filepath.ToSlash(rel)
		out = append(out, p)
		return nil
	})
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out, err
}

// LoadUnitCases reads every tests/unit/**/*.json into path -> cases.
func LoadUnitCases(root string) (map[string][]UnitCase, error) {
	out := map[string][]UnitCase{}
	base := filepath.Join(root, "tests", "unit")
	err := filepath.WalkDir(base, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".json") {
			return err
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var generic []map[string]json.RawMessage
		if err := json.Unmarshal(raw, &generic); err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		var cases []UnitCase
		if err := json.Unmarshal(raw, &cases); err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		for i := range cases {
			_, cases[i].HasParam = generic[i]["param"]
		}
		rel, _ := filepath.Rel(root, path)
		out[filepath.ToSlash(rel)] = cases
		return nil
	})
	return out, err
}

// latin1 encodes a byte string (every code point <= U+00FF) as its bytes.
func latin1(s string) []byte {
	b := make([]byte, 0, len(s))
	for _, r := range s {
		if r > 0xFF {
			panic(fmt.Sprintf("unit string has a code point above U+00FF: %q", s))
		}
		b = append(b, byte(r))
	}
	return b
}

// escapeParam makes a byte string safe inside a double-quoted directive argument. The
// only escape the engines process is \" (01-lexical.md#quoting-and-escapes); every other
// backslash is literal, so backslashes are left alone.
func escapeParam(p string) string {
	return strings.ReplaceAll(p, `"`, `\"`)
}

// byteString turns raw engine bytes into the one-code-point-per-byte form of tests/unit.
func byteString(b []byte) string {
	r := make([]rune, len(b))
	for i, c := range b {
		r[i] = rune(c)
	}
	return string(r)
}
