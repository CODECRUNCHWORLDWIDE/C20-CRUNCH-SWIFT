# Week 15 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 15 Git repository so each problem produces at least one commit you can point to later. **Several require a physical device + paid account** — the Simulator can't give honest numbers, which is the week's whole premise.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**. Every measurement must be on a **Release build on a physical device**.

---

## Problem 1 — Inspect a signed build

**Problem statement.** Deploy any app to your device, then use the command line to inspect the signed `.app`. In `notes/signing-anatomy.md`, record: who signed it (`codesign -dvvv`), what entitlements it claims (`codesign -d --entitlements :-`), and what's in the embedded provisioning profile (`security cms -D -i .../embedded.mobileprovision`). Write one sentence mapping each output to one of the four pieces (certificate, App ID, device list, entitlements).

**Acceptance criteria.**

- `notes/signing-anatomy.md` has the three outputs (quoted from your actual build) and the four-piece mapping.
- Committed.

**Hint.** The built `.app` is under `~/Library/Developer/Xcode/DerivedData/<proj>/Build/Products/Release-iphoneos/`. The entitlements output shows your `aps-environment`/`application-groups`/`icloud` keys if you've enabled those capabilities.

**Estimated time.** 35 minutes.

---

## Problem 2 — Read a flame graph and name the spike

**Problem statement.** Take the heavy-screen app from exercise 1 (or Notes v1). Profile it on the device with the Time Profiler, find the function with the highest self time on the main thread, and write `notes/flame-graph.md`: the function name, its self time, its thread, and the call path from `body` down to it. Then state how you'd fix it without changing the function's logic (move it off-main / precompute).

**Acceptance criteria.**

- `notes/flame-graph.md` names the hot function, its self time, its thread, and the call path.
- The fix described is "move off the main thread / precompute," not "make the function faster."
- Committed.

**Hint.** "Hide System Libraries" in the Call Tree options surfaces your code. Heaviest Stack Trace gives you the hottest path in one click.

**Estimated time.** 40 minutes.

---

## Problem 3 — Fix a SwiftData main-thread hang with a `@ModelActor`

**Problem statement.** In a SwiftData app, plant a hang: do a big synchronous fetch + transform on the main context inside a button action so the UI freezes. Find it in the Hangs instrument, then fix it by moving the work to a `@ModelActor` background context that returns a `Sendable` result, with a main-thread `@Query` (or a re-fetch) showing the result. Record the before/after in `notes/swiftdata-hang.md`.

**Acceptance criteria.**

- A reproducible hang (UI freezes) from a synchronous main-context operation.
- A `@ModelActor` that does the work off-main and returns a `Sendable` value (never a `ModelContext` or model object crosses the boundary).
- The UI stays responsive after the fix.
- 0 strict-concurrency warnings. Committed.

**Hint.** `@ModelActor actor Importer { func process() async throws -> Int { ... } }`. Pass the `Sendable` `ModelContainer` in; never capture the view's `@Environment` context. This is the Week 10 background pattern applied to a hang.

**Estimated time.** 50 minutes.

---

## Problem 4 — Hunt a retain-cycle leak

**Problem statement.** Plant a retain cycle: a long-lived object stores a closure that captures `self` strongly (a Combine sink or a callback). Confirm with the Leaks instrument (or persistent-memory growth in Allocations across navigation cycles) that it leaks, then fix it with `[weak self]` and confirm the leak is gone. Use the Memory Graph to show the cycle before the fix. Record both in `notes/leak.md`.

**Acceptance criteria.**

- A reproducible leak (Leaks flags it, or persistent memory climbs each navigation cycle).
- The Memory Graph screenshot showing the cycle.
- The `[weak self]` fix, after which the leak is gone.
- 0 warnings. Committed.

**Hint.** `onUpdate = { self.refresh() }` leaks; `onUpdate = { [weak self] in self?.refresh() }` doesn't. Navigate in/out of the screen several times and watch persistent memory; the Memory Graph's three-circle button shows the retain chain.

**Estimated time.** 45 minutes.

---

## Problem 5 — Signpost an operation and read it in the trace

**Problem statement.** Wrap a real operation in your app (a fetch, a render, an import) in an `OSSignposter` interval. Profile the app, find your named interval in the os_signpost / Points of Interest track, and screenshot it lined up against the Time Profiler track. In `notes/signpost.md`, explain what the signpost told you that the raw Time Profiler didn't (which of *your* operations the CPU cost belonged to).

**Acceptance criteria.**

- An `OSSignposter` interval (with a `StaticString` name) around a real operation.
- A screenshot showing the named interval in the trace.
- `notes/signpost.md` explains the correlation the signpost gave you.
- 0 warnings. Committed.

**Hint.** Use the `signposted("name") { }` helper from exercise 3. Add the os_signpost instrument (or a template that includes Points of Interest) so the region shows up. The name must be a literal, not a variable.

**Estimated time.** 35 minutes.

---

## Problem 6 — Wire a MetricKit collector and forward a payload

**Problem statement.** Register an `MXMetricManagerSubscriber` that receives `MXMetricPayload` and `MXDiagnosticPayload`. Log the byte count and one extracted field from each. Then write a `forward(_:)` stub that would `POST` `payload.jsonRepresentation()` to a backend (you don't need a live server — just the function and a `Logger` line proving you'd send it). Use Xcode's *Debug ▸ Simulate MetricKit Payloads* to receive one during development.

**Acceptance criteria.**

- A `MetricsCollector: MXMetricManagerSubscriber` registered early, logging both payload types.
- A `forward(_:)` that takes `jsonRepresentation()` and would POST it (a `URLRequest` built, or a clear stub).
- You received at least one (simulated) payload and logged it.
- 0 warnings. Committed.

**Hint.** `MXMetricManager.shared.add(self)` in `App.init`. Payloads arrive once per day on a real device — use the Debug ▸ Simulate menu to get one immediately. `jsonRepresentation()` is exactly what you'd upload.

**Estimated time.** 45 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic, the measurement is on-device/Release, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor issue (e.g. a slightly imprecise flame-graph reading, a missing screenshot). |
| 3 | Works, but misses one criterion (e.g. measured in the Simulator, hang "fixed" by speeding up the function, leak not actually broken). |
| 2 | Compiles and partially works; a core idea is wrong (optimized the wrong axis, suppressed a concurrency warning instead of moving work off-main). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−3** for a performance number measured in the Simulator or a Debug build (it's worse than no number); **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) used to silence the compiler instead of restructuring; **−2** for "fixing" a hang by making the slow work faster instead of moving it off-main; **−1** for a performance claim with no before/after.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — reading a flame graph (problems 2, 5) and "a hang is work that belongs off the main thread" (problems 3) — so re-run exercises 01 and 02 before resubmitting.
