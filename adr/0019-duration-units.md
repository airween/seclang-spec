# ADR-0019: `DURATION` is wall-clock microseconds since the engine created the transaction

- **Status:** accepted
- **Date:** 2026-10-06
- **Accepted:** 2026-11-11
- **Deciders:** @fzipi, @xanadu, @M4tteoP, @airween, @franbuehler, @theseion
- **Category:** Divergence

## Context

All three engines expose a `DURATION` variable with three incompatible meanings:

- ModSecurity v2 (v2.9.15): wall-clock microseconds, `apr_time_now() - msr->r->request_time`
  (`apache2/re_variables.c`, `var_duration_generate`). The start point is the host's, not
  the engine's. On Apache, httpd sets `r->request_time` once it has read the request line
  (`server/protocol.c`, `read_request_line`, httpd 2.4.x), then reads the headers, and only
  then runs the `post_read_request` hooks where ModSecurity creates its transaction
  (`apache2/mod_security2.c`, `hook_request_early` → `create_tx_context`). So the value
  includes the time the client took to send its headers. The standalone connector used by
  the v2 nginx module (`standalone/main.cpp`) and the IIS module (`iis/mymodule.cpp`) set
  `request_time = apr_time_now()` when they build the request record instead.
- libmodsecurity v3 (v3.0.17): process CPU seconds as a decimal fraction,
  `utils::cpu_seconds() - m_creationTimeStamp` (`src/variables/duration.cc`).
  `cpu_seconds` reads `CLOCK_PROCESS_CPUTIME_ID` (`src/utils/system.cc`), which counts
  every thread of the process, so under concurrent traffic the value includes other
  transactions' work. The start point is the `Transaction` constructor
  (`src/transaction.cc`).
- Coraza (v3.8.1): the constant `"0"` (`internal/corazawaf/waf.go`). The same function sets
  `tx.Timestamp = time.Now().UnixNano()` when it creates the transaction, so the start
  point is already recorded.

The manuals disagree too. The v2 reference manual says "milliseconds elapsed since the
beginning of the current transaction" (from 2.6.0) and adds "Starting with ModSecurity
2.7.0 the time is microseconds", which is what v2 reports. The v3 reference manual says
milliseconds. Coraza documents the variable as not implemented
(`internal/variables/variables.go`). No published ruleset reads `DURATION`.

The first version of this ADR left the unit and clock unspecified. It was amended on
2026-11-11, before acceptance, to fix both; microseconds were chosen over milliseconds the same
day, after the v2 manual's 2.7.0 note was checked.

## Decision

`DURATION` is the wall-clock time elapsed since the engine created the transaction, in
whole microseconds, written as a base-10 integer with no sign, fraction or unit
(truncated, not rounded). The transaction is created when the host hands the request to
the engine (v2 `create_tx_context`, v3 `msc_new_transaction`, Coraza `NewTransaction`);
time the host spent before that, such as reading the request headers, is not counted.

`DURATION` stays Extended.

## Options considered

- **Fix the unit and the clock, keep it Extended (chosen).** One meaning for slow-request
  rules, an integer that `@gt` and `@lt` compare, and a value that a test can check. No
  engine is required to implement it.
- **Microseconds (chosen) or milliseconds.** Microseconds are what v2 has documented and
  reported since 2.7.0, so v2 keeps its unit and no existing v2 rule changes meaning; they
  are also fine enough that a fast request rarely reads 0, and a 64-bit integer holds
  centuries of them. Milliseconds match the v3 manual and v2's 2.6.0 text, but v3 does not
  implement them (it reports CPU seconds) and v2 users would see every value divided by
  1000. Milliseconds rejected.
- **Count from when the server received the request.** It would include slow header
  delivery, but only Apache records that moment: the v2 nginx and IIS connectors, v3 and
  Coraza never see it, so the value would mean something different per host. Slow-client
  defence belongs to the server (`mod_reqtimeout`). Rejected.
- **Process CPU time, as v3 reports.** It counts other transactions under concurrency and
  does not measure what a slow-request rule asks about. Rejected.
- **Leave the unit unspecified (this ADR's first version).** Rules cannot compare
  `DURATION` across engines, and no test can assert on it. Rejected.
- **Make it Core.** Every engine would be non-conforming today. Rejected.
- **Deprecate.** It is cheap to implement correctly and useful for slow-request rules.
  Rejected.

## Consequences

- For ModSecurity v2: take a timestamp in `create_tx_context` and report
  `apr_time_now() - start`. The unit is unchanged; on Apache the values get smaller by the
  time spent reading the request headers.
- For libmodsecurity v3: record a monotonic wall-clock time in the `Transaction`
  constructor and report integer microseconds. Internal state only; it fits 3.x. The v3
  reference manual's "milliseconds" needs correcting.
- For Coraza: report `(time.Now().UnixNano() - tx.Timestamp) / 1000`.
- For rule authors: `DURATION` compares across engines once they implement this ADR;
  until then, profiles that need it declare `requires:`.
- Black-box tests can check only the form of the value and a sanity bound, not its unit
  or clock: a very fast request can legitimately report 0.

## Tests

- `tests/engine/variables/duration.yaml`

## References

- `spec/05-variables.md#duration`
- `https://github.com/apache/httpd/blob/2.4.x/server/protocol.c` (`read_request_line`)
