// Command differential drives Coraza with seeded random requests against every Core
// engine profile's ruleset and writes what Coraza did, in the engine-profile JSON shape
// that formal/EvalMain.lean reads (the same shape as tools/engine_rules.py), so that
// `lake exe seclang-eval` can check that the Lean model agrees with the engine on inputs
// no hand-written profile anticipated.
//
//	cd adapters/coraza && go run ./cmd/differential -n 30 -seed 1 > ../../formal/.lake/differential.json
//	cd formal && lake exe seclang-eval .lake/differential.json
//
// Skipped: profiles with `requires:` (Extended), with a Coraza row in compat/known-gaps.md
// (the engine deviates from the specification there by record), with expect_error or log
// assertions, and any request on which the engine panicked.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"math/rand"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	adapter "github.com/OWASP/seclang-spec/adapters/coraza"
	"gopkg.in/yaml.v3"
)

type profileOut struct {
	Path        string            `json:"path"`
	Rules       string            `json:"rules"`
	Files       map[string]string `json:"files"`
	ExpectError bool              `json:"expect_error"`
	Tests       []testOut         `json:"tests"`
}
type testOut struct {
	Title  string     `json:"test_title"`
	Stages []stageOut `json:"stages"`
}
type stageOut struct {
	Stage stageBody `json:"stage"`
}
type stageBody struct {
	Input    inputOut    `json:"input"`
	Response responseOut `json:"response"`
	Output   outputOut   `json:"output"`
}
type inputOut struct {
	Method     string            `json:"method"`
	URI        string            `json:"uri"`
	Version    string            `json:"version,omitempty"`
	Headers    map[string]string `json:"headers"`
	Data       string            `json:"data,omitempty"`
	RemoteAddr string            `json:"remote_addr,omitempty"`
}

// vocab says which request dimensions the profile's rules can observe, so the generator
// varies them only there (every other dimension stays at its default).
type vocab struct {
	method, path, addr, proto, cookies bool
	argSep                             string
}

func vocabOf(rules string) vocab {
	v := vocab{argSep: "&"}
	v.method = strings.Contains(rules, "REQUEST_METHOD") || strings.Contains(rules, "REQUEST_LINE")
	v.path = regexp.MustCompile(`REQUEST_URI|REQUEST_FILENAME|REQUEST_BASENAME|PATH_INFO|REQUEST_LINE`).MatchString(rules)
	v.addr = strings.Contains(rules, "REMOTE_ADDR") || strings.Contains(rules, "@ipMatch")
	v.proto = strings.Contains(rules, "REQUEST_PROTOCOL") || strings.Contains(rules, "REQUEST_LINE")
	v.cookies = strings.Contains(rules, "REQUEST_COOKIES")
	if m := regexp.MustCompile(`SecArgumentSeparator (\S)`).FindStringSubmatch(rules); m != nil {
		v.argSep = m[1]
	}
	return v
}

var paths = []string{"/", "/index.php", "/a/b", "/dir/file.php", "/x%20y", "/a/./b/../c.php", "/dir/file.php/extra",
	"/%2e%2e/etc/passwd", "/a%2fb", "/x;y", "/index.php;jsessionid=1", "/a//b", "/UPPER/Case.PHP", "/\u00fc", "/a%00b", "/.hidden/", "/a/"}
var methods = []string{"GET", "GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH", "TRACE", "WEIRD"}
var addrs = []string{"127.0.0.1", "10.1.2.3", "192.168.0.1", "203.0.113.9", "::1", "2001:db8::1", "10.255.255.255", "11.0.0.1", "0.0.0.0"}
var versions = []string{"HTTP/1.1", "HTTP/1.1", "HTTP/1.0", "HTTP/2"}

type responseOut struct {
	Status  int               `json:"status"`
	Headers map[string]string `json:"headers"`
	Data    string            `json:"data"`
}
type outputOut struct {
	TriggeredRules    []int                   `json:"triggered_rules"`
	NonTriggeredRules []int                   `json:"non_triggered_rules"`
	Interruption      *map[string]interface{} `json:"interruption,omitempty"`
	NoInterruption    bool                    `json:"no_interruption,omitempty"`
}

var (
	reID             = regexp.MustCompile(`\bid:(\d+)`)
	reArg            = regexp.MustCompile(`ARGS(?:_GET|_POST)?:([A-Za-z0-9_.-]+)`)
	reHeader         = regexp.MustCompile(`REQUEST_HEADERS:([A-Za-z0-9_-]+)`)
	reCookie         = regexp.MustCompile(`REQUEST_COOKIES:([A-Za-z0-9_-]+)`)
	reParam          = regexp.MustCompile(`"!?@[A-Za-z]+ ([^"]{1,40})"`)
	reNumericOp      = regexp.MustCompile(`@(eq|ge|gt|le|lt)\b`)
	reBodyLimit      = regexp.MustCompile(`SecRequestBodyLimit (\d+)`)
	reRespLimit      = regexp.MustCompile(`SecResponseBodyLimit (\d+)`)
	reRequestBody    = regexp.MustCompile(`\bREQUEST_BODY\b`)
	reMime           = regexp.MustCompile(`SecResponseBodyMimeType ([^\n]+)`)
	reDigitsThenText = regexp.MustCompile(`^[+-]?\d+[^\d]`)
)

var generic = []string{"", "1", "2", "0", "x", "abc", "foo bar", "FOO", "1.0", "-1", "a=b", "a,b", "a;b",
	"<script>", "../../etc/passwd", "' OR 1=1", "%27", "%00", "+", "&", "%2F", "/a/./b/../c", "ÿ",
	"user-42", "user-x", "hello world", "secret", "forbidden", "10.1.2.3", "203.0.113.9", "a b c", "  ", "AbC"}

func uniq(ss []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range ss {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	sort.Strings(out)
	return out
}

func captures(re *regexp.Regexp, text string) []string {
	var out []string
	for _, m := range re.FindAllStringSubmatch(text, -1) {
		out = append(out, m[1])
	}
	return uniq(out)
}

func pick(r *rand.Rand, xs []string) string { return xs[r.Intn(len(xs))] }

// mutate returns the value or a near miss of it, so matching and non-matching inputs both appear.
func mutate(r *rand.Rand, v string) string {
	switch r.Intn(8) {
	case 0:
		return strings.ToUpper(v)
	case 1:
		return v + "x"
	case 2:
		return "x" + v
	case 3:
		return url.QueryEscape(v)
	case 4:
		return v + v
	default:
		return v
	}
}

func main() {
	n := flag.Int("n", 30, "requests per profile")
	seed := flag.Int64("seed", 1, "random seed")
	single := flag.String("profile", "", "run this one profile file (engine-profile YAML) instead of tests/engine")
	flag.Parse()
	root := adapter.RepoRoot()
	var profiles []adapter.Profile
	var err error
	if *single != "" {
		profiles, err = loadOne(*single)
	} else {
		profiles, err = adapter.LoadProfiles(root)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	gaps, err := adapter.LoadGaps(filepath.Join(root, "compat", "known-gaps.md"), "coraza")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	var out []profileOut
	skipped := 0
	for pi, p := range profiles {
		if len(p.Requires) > 0 || gaps[p.Path] != "" || unsuited(p) {
			skipped++
			continue
		}
		dir, _ := os.MkdirTemp("", "diff")
		waf, log, err := adapter.BuildWAF(p, dir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: cannot load: %v\n", p.Path, err)
			os.RemoveAll(dir)
			skipped++
			continue
		}
		r := rand.New(rand.NewSource(*seed*1000003 + int64(pi)))
		ids := idsOf(p.Rules)
		args := append(captures(reArg, p.Rules), "a", "b", "q")
		headers := append(captures(reHeader, p.Rules), "X-Test")
		cookies := captures(reCookie, p.Rules)
		values := append(captures(reParam, p.Rules), generic...)
		if reNumericOp.MatchString(p.Rules) {
			// 06#eq: leading digits followed by text convert differently per engine and are
			// unspecified, so a numeric profile never sees such a value.
			var kept []string
			for _, v := range values {
				if !reDigitsThenText.MatchString(v) {
					kept = append(kept, v)
				}
			}
			values = kept
		}
		wantsBody := strings.Contains(p.Rules, "ARGS_POST") || strings.Contains(p.Rules, "REQUEST_BODY") ||
			strings.Contains(p.Rules, "REQBODY") || strings.Contains(p.Rules, "FILES") || strings.Contains(p.Rules, "MULTIPART") ||
			regexp.MustCompile(`\bARGS\b`).MatchString(p.Rules)
		kinds := []string{"urlencoded"}
		// REQUEST_BODY is unspecified for a body no processor parsed (ADR-0022): a profile that
		// reads it only gets URL-encoded bodies.
		readsRequestBody := reRequestBody.MatchString(p.Rules)
		if strings.Contains(strings.ToLower(p.Rules), "requestbodyprocessor=json") && !readsRequestBody {
			kinds = append(kinds, "json", "json")
		}
		if (strings.Contains(p.Rules, "MULTIPART") || strings.Contains(p.Rules, "FILES")) && !readsRequestBody {
			kinds = append(kinds, "multipart", "multipart")
		}
		// known gap (compat/known-gaps.md, files-combined-size-fields.yaml): Coraza counts field
		// bytes in FILES_COMBINED_SIZE, so such a profile only gets file parts.
		filesOnly := strings.Contains(p.Rules, "FILES_COMBINED_SIZE")
		wantsResponse := strings.Contains(p.Rules, "RESPONSE_")
		// known gap (secresponsebodylimit-uninspected.yaml): Coraza enforces the response limit on
		// uninspected types, so a profile with a response limit only sees its inspected types.
		inspected := captures(reMime, p.Rules)
		if !strings.Contains(p.Rules, "SecResponseBodyLimit") {
			inspected = nil
		}
		// a body of exactly SecRequestBodyLimit bytes is a recorded Coraza gap (>=); never generate one
		avoid := map[int]bool{}
		for _, m := range reBodyLimit.FindAllStringSubmatch(p.Rules, -1) {
			n, _ := strconv.Atoi(m[1])
			avoid[n] = true
		}
		avoidResp := map[int]bool{} // same gap on the response side (secresponsebodylimit-boundary.yaml)
		for _, m := range reRespLimit.FindAllStringSubmatch(p.Rules, -1) {
			n, _ := strconv.Atoi(m[1])
			avoidResp[n] = true
		}
		po := profileOut{Path: p.Path + "#differential", Rules: p.Rules, Files: p.Files}
		if po.Files == nil {
			po.Files = map[string]string{}
		}
		for k := 0; k < *n; k++ {
			kind := ""
			if wantsBody && r.Intn(3) > 0 {
				kind = pick(r, kinds)
			}
			in := genInput(r, args, headers, cookies, values, kind, reNumericOp.MatchString(p.Rules), filesOnly, vocabOf(p.Rules))
			if avoid[len(in.Data)] {
				in.Data += " "
			}
			resp := responseOut{Status: 200, Headers: map[string]string{"Content-Type": "text/plain"}, Data: "ok"}
			if wantsResponse {
				resp = genResponse(r, values, inspected)
				if avoidResp[len(resp.Data)] {
					resp.Data += " "
				}
			}
			stage := adapter.Stage{Input: adapter.Input{Method: in.Method, URI: in.URI, Version: in.Version, Headers: in.Headers, Data: in.Data, RemoteAddr: in.RemoteAddr},
				Response: &adapter.Response{Status: resp.Status, Headers: resp.Headers, Data: resp.Data}}
			obs := adapter.RunStage(waf, log, stage)
			if obs.Panic != "" {
				continue
			}
			o := outputOut{}
			for _, id := range ids {
				if obs.Triggered[id] {
					o.TriggeredRules = append(o.TriggeredRules, id)
				} else {
					o.NonTriggeredRules = append(o.NonTriggeredRules, id)
				}
			}
			if obs.Interruption != nil {
				m := map[string]interface{}{"rule_id": obs.Interruption.RuleID, "action": obs.Interruption.Action}
				o.Interruption = &m
			} else {
				o.NoInterruption = true
			}
			po.Tests = append(po.Tests, testOut{Title: fmt.Sprintf("gen %d", k), Stages: []stageOut{{Stage: stageBody{
				Input: in, Response: resp, Output: o}}}})
		}
		os.RemoveAll(dir)
		out = append(out, po)
	}
	fmt.Fprintf(os.Stderr, "%d profiles generated, %d skipped\n", len(out), skipped)
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(out); err != nil {
		os.Exit(2)
	}
}

// loadOne reads one engine-profile YAML file; its path is the file's base name.
func loadOne(path string) ([]adapter.Profile, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var p adapter.Profile
	if err := yaml.Unmarshal(raw, &p); err != nil {
		return nil, err
	}
	p.Path = filepath.Base(path)
	return []adapter.Profile{p}, nil
}

// unsuited: expect_error profiles and log assertions, which the model does not carry.
func unsuited(p adapter.Profile) bool {
	for _, t := range p.Tests {
		for _, s := range t.Stages {
			if s.Stage.Output.ExpectError || s.Stage.Output.LogContains != "" || s.Stage.Output.NoLogContains != "" {
				return true
			}
		}
	}
	return false
}

func idsOf(rules string) []int {
	var ids []int
	for _, m := range reID.FindAllStringSubmatch(rules, -1) {
		id, _ := strconv.Atoi(m[1])
		ids = append(ids, id)
	}
	sort.Ints(ids)
	return ids
}

// genResponse varies status, content type and body for profiles with response-phase rules.
func genResponse(r *rand.Rand, values []string, inspected []string) responseOut {
	ct := pick(r, []string{"text/plain", "text/html; charset=utf-8", "application/json", "text/plain", "image/png"})
	if len(inspected) > 0 {
		ct = pick(r, strings.Fields(strings.Join(inspected, " ")))
	}
	body := pick(r, append([]string{"ok", "<html>hi</html>", "{\"a\":1}", "SQL syntax error near", "password=secret", "0123456789"}, values...))
	return responseOut{Status: pickInt(r, []int{200, 200, 404, 500, 302}), Headers: map[string]string{"Content-Type": ct}, Data: body}
}

func pickInt(r *rand.Rand, xs []int) int { return xs[r.Intn(len(xs))] }

func genInput(r *rand.Rand, args, headers, cookies, values []string, kind string, numeric bool, filesOnly bool, vb vocab) inputOut {
	in := inputOut{Method: "GET", Headers: map[string]string{}}
	if vb.method {
		in.Method = pick(r, methods)
	}
	if vb.addr {
		in.RemoteAddr = pick(r, addrs)
	}
	if vb.proto {
		in.Version = pick(r, versions)
	}
	value := func() string {
		for {
			v := mutate(r, pick(r, values))
			if !numeric || !reDigitsThenText.MatchString(v) {
				return v
			}
		}
	}
	var q []string
	for i := r.Intn(4); i > 0; i-- {
		name, val := url.QueryEscape(pick(r, args)), value()
		switch r.Intn(10) {
		case 0:
			q = append(q, name) // no `=`
		case 1:
			q = append(q, "="+url.QueryEscape(val)) // empty name
		case 2:
			if numeric { // `1=x` is digits then text, unspecified for 06#eq
				q = append(q, name+"="+url.QueryEscape(val))
				break
			}
			q = append(q, name+"="+url.QueryEscape(val)+"=x") // `=` inside the value
		case 3:
			q = append(q, name+"="+strings.ReplaceAll(url.QueryEscape(val), "+", "%20"))
		case 4:
			q = append(q, name+"="+url.QueryEscape(url.QueryEscape(val))) // double-encoded
		default:
			q = append(q, name+"="+url.QueryEscape(val))
		}
	}
	path := "/"
	if vb.path {
		path = pick(r, paths)
	} else if r.Intn(3) == 0 {
		path = "/" + pick(r, []string{"index.php", "a/b", "dir/file.php", "x%20y", ".."})
	}
	in.URI = path
	if len(q) > 0 {
		in.URI += "?" + strings.Join(q, vb.argSep)
	}
	for i := r.Intn(3); i > 0; i-- {
		// a server strips the optional whitespace around a field value before the engine sees it
		// (tests/README.md), so header values never carry surrounding spaces here
		v := strings.TrimSpace(value())
		switch r.Intn(6) {
		case 0:
			v = v + ", " + strings.TrimSpace(value())
		case 1:
			v = ""
		}
		in.Headers[pick(r, headers)] = v
	}
	// every HTTP/1.1 request carries a Host header; the adapters add one when it is missing
	if _, ok := in.Headers["Host"]; !ok {
		in.Headers["Host"] = "localhost"
	}
	if (len(cookies) > 0 || vb.cookies) && r.Intn(3) > 0 {
		names := append(cookies, "sid", "a")
		var cs []string
		for i := 1 + r.Intn(3); i > 0; i-- {
			name, val := pick(r, names), value()
			switch r.Intn(6) {
			case 0:
				val = "\"" + val + "\""
			case 1:
				val = ""
			case 2:
				val = val + "=" + val
			}
			cs = append(cs, name+"="+val)
		}
		in.Headers["Cookie"] = strings.Join(cs, "; ")
	}
	switch kind {
	case "urlencoded":
		in.Method = "POST"
		var b []string
		for i := 1 + r.Intn(3); i > 0; i-- {
			b = append(b, url.QueryEscape(pick(r, args))+"="+url.QueryEscape(value()))
		}
		in.Headers["Content-Type"] = "application/x-www-form-urlencoded"
		in.Data = strings.Join(b, "&")
	case "json":
		in.Method = "POST"
		in.Headers["Content-Type"] = "application/json"
		switch r.Intn(6) {
		case 0:
			in.Data = "{\"" + pick(r, args) + "\":" // malformed
		case 1:
			in.Data = "[1,[2,[3,[4]]]]"
		default:
			var kv []string
			for i := 1 + r.Intn(3); i > 0; i-- {
				v, _ := json.Marshal(value())
				kv = append(kv, "\""+pick(r, args)+"\":"+string(v))
			}
			in.Data = "{" + strings.Join(kv, ",") + "}"
			if r.Intn(3) == 0 {
				in.Data = "{\"" + pick(r, args) + "\":" + in.Data + "}"
			}
		}
	case "multipart":
		in.Method = "POST"
		in.Headers["Content-Type"] = "multipart/form-data; boundary=XX"
		var parts []string
		for i := 1 + r.Intn(2); i > 0 && !filesOnly; i-- {
			parts = append(parts, "--XX\r\nContent-Disposition: form-data; name=\""+pick(r, args)+"\"\r\n\r\n"+value()+"\r\n")
		}
		if filesOnly || r.Intn(2) == 0 {
			name := pick(r, []string{"a.txt", "shell.php", "x.png", "a b.txt"})
			parts = append(parts, "--XX\r\nContent-Disposition: form-data; name=\"f\"; filename=\""+name+"\"\r\nContent-Type: text/plain\r\n\r\n"+value()+"\r\n")
		}
		in.Data = strings.Join(parts, "") + "--XX--\r\n"
	}
	return in
}
