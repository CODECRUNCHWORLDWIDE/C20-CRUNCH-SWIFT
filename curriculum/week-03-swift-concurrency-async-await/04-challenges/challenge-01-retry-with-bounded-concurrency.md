# Challenge 1 — `--retry` with Bounded Concurrency That Drains Cleanly on Ctrl-C

**Time estimate:** ~120 minutes.

## Prerequisite

Do the [mini-project](../07-mini-project/00-overview.md) first, or at least scaffold its package and get the basic fan-out working. This challenge adds a feature *on top of* the link-checker — it assumes you already have `check(url:)`, a bounded `TaskGroup`, a `--concurrency` flag, a `--timeout`, and the `SIGINT` trap from the mini-project.

## Problem statement

A real link-checker hits transient failures: a 503 under load, a connection reset, a DNS hiccup, a timeout on a slow CDN. Failing those URLs permanently on the first try produces a report full of false negatives. Production link-checkers retry.

Add a `--retry N` flag (default `0` — no retries) that re-runs **failed** `HEAD` requests up to `N` additional times, with **exponential backoff and jitter** between attempts, under their **own concurrency cap**, and — this is the part that earns the challenge — proves that hitting **Ctrl-C while retries are in flight (including mid-backoff)** still cancels and drains every in-flight retry cleanly, with no hang and no leaked task.

```bash
# Retry each failed URL up to 3 times, base concurrency 16, retry concurrency 4.
swift run linkcheck --sitemap sitemap.xml --retry 3 --retry-concurrency 4 --timeout 5
```

### What counts as "failed" and therefore retryable

- A thrown transport error (timeout, connection reset, DNS failure) → retryable.
- An HTTP `5xx` status → retryable.
- An HTTP `429 Too Many Requests` → retryable (honour `Retry-After` if present as a stretch).
- An HTTP `4xx` other than `429` → **not** retryable (a `404` is a real dead link; retrying it is wrong).
- An HTTP `2xx`/`3xx` → success, never retried.

This classification is the design heart of the challenge. Model it as a function:

```swift
enum Retryability: Sendable {
    case success(Int)        // HTTP status code
    case deadLink(Int)       // 4xx (except 429) — permanent, do not retry
    case transient(String)   // retryable: 5xx, 429, or a transport error description
}
```

### Backoff with jitter

Between retry attempt `k` (0-based), wait roughly `base * 2^k`, with **full jitter** so a thundering herd of retries doesn't re-synchronise:

```swift
// Full-jitter exponential backoff. base = 200ms by default.
func backoff(attempt k: Int, base: Duration = .milliseconds(200)) -> Duration {
    let ceiling = base * (1 << k)                          // base * 2^k
    let cappedMillis = min(ceiling.components.seconds * 1000
        + ceiling.components.attoseconds / 1_000_000_000_000_000, 5_000)  // cap at 5s
    let jittered = Int.random(in: 0...Int(cappedMillis))
    return .milliseconds(jittered)
}
```

The backoff wait **must** be a cancellable `try await Task.sleep(for:)`, never `Thread.sleep`. That single choice is what makes "Ctrl-C mid-backoff" drain instantly instead of hanging for up to five seconds.

## The cancellation requirement (the actual challenge)

The happy path — "retry failed URLs N times" — is about 30 minutes of work. The other 90 minutes is making this hold:

> When the user hits **Ctrl-C while retries are in flight** — including while a retry task is parked in its backoff `Task.sleep` — every in-flight retry, every backoff sleep, and every in-flight `HEAD` request cancels and drains, the partial report prints, and the process exits in **well under one second**.

To prove it, your program must, on cancellation:

1. Stop scheduling new retries immediately (no new `addTask` after cancellation is observed).
2. Cancel every in-flight retry task — the backoff `Task.sleep` throws `CancellationError`, the in-flight `HEAD` request throws `URLError(.cancelled)` (or your `withTaskCancellationHandler` cancels the underlying request).
3. Print a partial report that distinguishes *checked*, *retrying-when-cancelled*, and *not-yet-attempted* URLs.
4. Exit without a "task continuation misuse" crash and without leaking a task past `main`.

## Acceptance criteria

- [ ] A `--retry N` flag (default `0`) and a `--retry-concurrency M` flag (default `4`) are parsed and respected.
- [ ] `swift build` (and `swift build -c release`) produce **no warnings and no errors**.
- [ ] With `--retry 0`, behaviour is identical to the mini-project (a true superset; no regression).
- [ ] Retryable failures (5xx, 429, transport errors) are retried up to `N` times; `4xx` (except 429) are **never** retried.
- [ ] Backoff is exponential with full jitter, capped at 5 s, and uses a **cancellable** `Task.sleep`.
- [ ] The retry phase runs under its **own** concurrency cap (`--retry-concurrency`), independent of the main `--concurrency`.
- [ ] **Ctrl-C while retries are in flight (including mid-backoff) drains in under 1 second** and prints a partial report. This is the bar; demonstrate it.
- [ ] No `Thread.sleep`, no `DispatchSemaphore.wait()`, no blocking I/O on a cooperative pool thread anywhere in the retry path.
- [ ] The final report counts: total URLs, OK, dead links (permanent), failed-after-retries, and (on cancellation) not-attempted.
- [ ] Swift Testing target proving (a) `4xx` is not retried, (b) a `transient` then `success` resolves to OK within `N` attempts, (c) backoff durations are monotonic-in-expectation and capped. Inject a fake checker so tests don't hit the network.
- [ ] Committed under `challenges/challenge-01/` in your Week 3 repo, with a `README.md` showing the new flags and a transcript of a clean Ctrl-C mid-retry.

## How to demonstrate the Ctrl-C drain

Point the checker at a deliberately flaky target. Two easy options:

- Run a tiny local server that returns `503` for the first request to each path and `200` afterward, so retries actually fire. A Vapor route from Week 5? Not yet — for now, a four-line Python `http.server` subclass or `httpbin`'s `https://httpbin.org/status/503` works.
- Use `https://httpbin.org/delay/10` for a handful of URLs so requests are slow enough that you can reliably hit Ctrl-C while they're in flight.

Record the transcript. It should look like:

```
checking 240 URLs (concurrency 16, retry 3, retry-concurrency 4, timeout 5s)…
  ✓ 198 OK
  ✗ 12 dead (4xx)
  ↻ 30 transient — entering retry phase
^C
caught SIGINT — cancelling 4 in-flight retries (2 mid-backoff)…
drained in 0.07 s. no leaked tasks.

partial report:
  checked:        210 / 240
  ok:             198
  dead links:     12
  retrying:       4   (cancelled)
  not attempted:  26
```

## Hints

<details>
<summary>Structuring the two phases</summary>

Run the main check as the mini-project does, collecting results. Partition results into `success`, `deadLink`, and `transient`. Then run a **second** bounded `TaskGroup` — the sliding-window pattern, capped at `--retry-concurrency` — over only the `transient` URLs, where each retry task loops up to `N` times with backoff between attempts:

```swift
func retryOnce(_ url: URL, maxAttempts: Int, base: Duration) async -> Retryability {
    var last: Retryability = .transient("not attempted")
    for k in 0..<maxAttempts {
        if k > 0 {
            try? await Task.sleep(for: backoff(attempt: k - 1, base: base))  // cancellable
            if Task.isCancelled { return last }   // bail if cancelled mid-backoff
        }
        last = await classify(url)                // one HEAD request, classified
        switch last {
        case .success, .deadLink: return last     // resolved — stop retrying
        case .transient:          continue        // try again after backoff
        }
    }
    return last
}
```

The whole retry phase lives inside a bounded `withTaskGroup`, so cancelling the root cancels the group, which cancels each `retryOnce` child, whose `Task.sleep` and HEAD request both throw — clean drain.

</details>

<details>
<summary>Why the backoff sleep is the crux</summary>

If you sleep with anything other than `Task.sleep`, Ctrl-C cannot interrupt it. A retry parked in a 5-second `Thread.sleep` will make your process hang for up to 5 seconds after Ctrl-C — failing the "under 1 second" bar. `Task.sleep(for:)` throws `CancellationError` the instant the task is cancelled, so a cancelled backoff returns immediately. This is the entire reason the lectures hammer "never block a cooperative pool thread."

</details>

<details>
<summary>Counting "not attempted" correctly</summary>

Track an index/cursor the way the sliding window does. On cancellation, "checked" is what you've collected, "retrying" is the size of the in-flight window at cancellation time, and "not attempted" is the remainder of the transient list you never started. Keep these as plain `Int`s you compute from the cursor — don't try to mutate a shared counter from inside concurrent children (that's a data race; Week 4 makes the compiler reject it).

</details>

## Why this matters

This exact pattern — bounded retry with jittered backoff, cooperative cancellation that drains cleanly — is **Week 13** (the production `URLSession` networking layer) almost verbatim, and it is a standard senior-iOS interview question ("how do you implement retry-with-backoff that respects cancellation?"). Building it now in a CLI, where Ctrl-C makes a leaked or hung task *visible*, means that by Week 13 it's muscle memory rather than theory. The discipline you prove here — "my concurrent program drains cleanly on cancellation" — is the same discipline that keeps an iOS app from spinning a request after the user has navigated away.
