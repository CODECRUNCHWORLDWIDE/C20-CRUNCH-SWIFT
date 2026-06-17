# Mini-Project — Notes v1: profiled on-device

This week Notes v1 runs on a real device, gets profiled with Instruments, and ships with a measured performance fix. You will **deploy** the app to a physical iPhone or iPad, **profile** it with the Time Profiler / Hangs / Animation Hitches instruments, find and fix **at least one main-thread hang and one scroll hitch**, prove each fix with a **before/after trace and a number**, and wire a **MetricKit collector** so the app keeps reporting performance once it's in the field.

This is a *compounding* project. It is not a new app. You start from Notes v1 — ideally the Week 14 version with Keychain + CloudKit, because CloudKit sync merges are a prime hang suspect — and you make it demonstrably fast on real hardware. No new features. The deliverable is *traces and numbers*: the discipline of "measure, fix, measure" applied to a real app.

> **This week requires the paid Apple Developer membership and a physical device.** Both are needed from day one. The Simulator cannot give honest performance numbers — a fix "proven" in the Simulator is not proven.

---

## Where you're starting from

Your Notes v1 app has, roughly:

- A SwiftData store (`Note`, `Tag`), possibly CloudKit-synced (Week 14), with a notes list and a detail editor.
- The Week 13 networking layer and the Week 14 Keychain-stored token.
- A `List` of notes, a detail view, tags, maybe note cover images.

If you don't have a clean Notes v1, a minimal SwiftData notes app with a list, a detail screen, and a few hundred seeded notes is enough — you need *enough data and UI* that the profiler has real work to find.

## What you're building toward

By the end you have:

- The app **deployed to a physical device** in a **Release** build (signing done, per lecture 1).
- A **Time Profiler** capture identifying the heaviest main-thread work.
- A fixed **main-thread hang** — a synchronous operation moved off `@MainActor` — with before/after Hangs traces.
- A fixed **scroll hitch** — expensive render-path work removed — with before/after Animation Hitches traces and a hitch-ratio number.
- A **MetricKit collector** logging the daily metric and diagnostic payloads.
- `os_signpost` intervals around the operations you profiled, so the next person can re-measure.
- A `PERF.md` documenting every fix as a before/after number.

---

## Milestone 1 — Deploy a Release build to your device (≈ 0.5 h)

Per lecture 1: select your Team (automatic signing), connect and trust the device, switch the scheme's Run config to **Release**, and ⌘R. Confirm the app runs on the device and behaves. If signing fails, work the troubleshooting chain (lecture 1, §7). This milestone is "the app is on real silicon, optimized." Everything after measures it.

Seed enough data: if your notes list has 20 rows, nothing will hitch. Seed a few hundred to a few thousand notes (a debug "seed" button) so the list, the queries, and any sync do enough work to surface problems.

## Milestone 2 — Baseline profile with the Time Profiler (≈ 1 h)

Capture a baseline so you know where the time goes before you change anything.

1. **Product ▸ Profile** (⌘I) → **Time Profiler**.
2. Record while you: cold-launch the app, scroll the notes list fast, open a note, return, and (if CloudKit) trigger a sync.
3. Read the main-thread track: find the heaviest self-time functions. Likely suspects, given the earlier weeks:
   - A **SwiftData relationship fault** per row (the N+1 from Week 10) — `note.tags` faulting as cells render.
   - A **synchronous fetch or transform** on the main context.
   - A **CloudKit merge** contending with a main-thread `@Query` re-fetch (Week 14).
   - An **image decode** on the scroll path (if notes have covers).
4. Write the baseline into `PERF.md`: the top main-thread costs, where they are, and which you'll fix.

Add `os_signpost` intervals around the operations you care about (note load, list render, sync merge) using the `signposted("name") { }` helper, so they appear as named regions correlated with the system tracks.

## Milestone 3 — Find and fix a main-thread hang (≈ 1.5 h)

1. Reproduce a **hang** — a moment the UI freezes. If Notes v1 doesn't naturally hang, induce a realistic one: an "export all notes" button that synchronously fetches every note and serializes it on the main context (a plausible feature done the wrong way).
2. Profile with the **Hangs** instrument (or watch the Time Profiler main-thread track during the freeze). Confirm the flagged stack is the synchronous operation.
3. **Fix it** by moving the work off `@MainActor`:
   - For a **SwiftData** operation, use a `@ModelActor` (Week 10) — a background context that does the fetch/serialize and returns a `Sendable` result (a `Data`, a count — never a `ModelContext` or model object).
   - For a **non-SwiftData** computation, `await Task.detached { ... }` and update the UI on the main actor.

```swift
// BEFORE — synchronous export hangs the UI.
@MainActor
func exportAll() {
    let all = try! context.fetch(FetchDescriptor<Note>())   // big fetch on main = freeze
    let data = try! JSONEncoder().encode(all.map(NoteDTO.init))
    try! data.write(to: exportURL, options: .atomic)
}

// AFTER — export off-main via a @ModelActor; only a Sendable Data crosses back.
@ModelActor
actor NotesExporter {
    func exportJSON() throws -> Data {
        let all = try modelContext.fetch(FetchDescriptor<Note>())
        return try JSONEncoder().encode(all.map(NoteDTO.init))   // DTO is Sendable
    }
}

@MainActor
func exportAll(container: ModelContainer) async throws {
    let exporter = NotesExporter(modelContainer: container)
    let data = try await exporter.exportJSON()               // off-main; UI stays responsive
    try data.write(to: exportURL, options: .atomic)          // atomic write, Week 14
}
```

4. Re-profile with Hangs and confirm the hang is **gone** — no flagged interval, the UI stays responsive. Record before/after in `PERF.md`: hang count (e.g. 1 → 0), and that the fix was *off-main*, not *faster*.

## Milestone 4 — Find and fix a scroll hitch (≈ 1.5 h)

1. Reproduce a **hitch** in the notes-list scroll. The most likely cause is a per-row relationship fault (`note.tags.count` in the cell) or a synchronous image decode (if notes have covers).
2. Profile with **Animation Hitches** while scrolling fast. Read the **hitch time ratio**. Screenshot the over-budget frames.
3. **Fix the render path:**
   - **N+1 fault:** prefetch the relationship — `descriptor.relationshipKeyPathsForPrefetching = [\Note.tags]` (Week 10) — so the cell doesn't fault per row.
   - **Image decode:** move it off-main and downsample to the cell size (the challenge's `ThumbnailCache` pattern) so the scroll path is cheap.
4. Re-profile, scroll the same way, read the new hitch ratio, screenshot the in-budget frames. Record before/after in `PERF.md`: hitch ratio (e.g. 38 ms/s → 3 ms/s) and the speedup.

```swift
// BEFORE — the cell faults tags per row on the scroll path.
struct NoteRow: View {
    let note: Note
    var body: some View {
        HStack {
            Text(note.title)
            Spacer()
            Text("\(note.tags.count)")   // faults per row -> N+1 -> hitch
        }
    }
}

// FIX — prefetch tags in the fetch so the relationship is already loaded.
var descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
descriptor.relationshipKeyPathsForPrefetching = [\Note.tags]
// (Or, in a @Query-driven list, bound the query and ensure tags aren't faulted per visible row.)
```

## Milestone 5 — Ship the MetricKit collector (≈ 1 h)

Wire the field telemetry so the app keeps reporting performance after it leaves your desk.

```swift
import MetricKit
import OSLog

let metricLog = Logger(subsystem: "com.crunch.notes", category: "metrickit")

final class MetricsCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsCollector()
    func start() { MXMetricManager.shared.add(self) }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads {
            metricLog.log("metrics: \(p.jsonRepresentation().count) bytes")
            if let r = p.applicationResponsivenessMetrics {
                metricLog.log("hang histogram buckets: \(r.histogrammedApplicationHangTime.totalBucketCount)")
            }
            // Phase IV: POST p.jsonRepresentation() to the Vapor backend.
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            for hang in p.hangDiagnostics ?? [] {
                metricLog.error("field hang: \(hang.hangDuration.description)")
            }
            for crash in p.crashDiagnostics ?? [] {
                metricLog.error("field crash: \(crash.terminationReason ?? "unknown")")
            }
        }
    }
}
```

Call `MetricsCollector.shared.start()` in `App.init`. Use **Debug ▸ Simulate MetricKit Payloads** to receive one during development and confirm your logging fires. Note in `PERF.md` that in production you'd forward `jsonRepresentation()` to the Vapor backend and aggregate across users.

## Milestone 6 — Write up the fixes (≈ 0.5 h)

`PERF.md` is the deliverable. It must contain, for each fix:

- The **device** (model + refresh rate) and that it was a **Release** build.
- The **before** number (hang count / hitch ratio) with a trace screenshot.
- The **after** number with a trace screenshot.
- The **cause** (in your words) and the **fix** (off-main / prefetch / downsample).
- One sentence on why the fix targets the *right* axis (off the main thread / off the render path, not "made it faster").

A `PERF.md` entry that would pass review reads like this:

> **Hang — export all notes.** iPhone 13, Release. Before: tapping "Export" froze the UI for ~1.2 s; the Hangs instrument flagged one severe hang with a stack ending in a synchronous `context.fetch` + `JSONEncoder.encode` on the main context. After: moved the fetch + encode to a `NotesExporter` `@ModelActor` returning `Data`; the UI stays fully responsive during export (Hangs flags nothing). The fix was getting the work off `@MainActor`, not making encoding faster — a synchronous encode of any size blocks the UI thread.
>
> **Hitch — notes list scroll.** iPhone 13 (60 Hz, 16.67 ms budget), Release. Before: hitch ratio 31 ms/s; Animation Hitches showed cell-appearance frames over budget, time spent faulting `note.tags` per row (the N+1 from Week 10). After: set `relationshipKeyPathsForPrefetching = [\Note.tags]` on the fetch; hitch ratio 2 ms/s, no over-budget frames — a ~15× improvement. The fix removed the per-row SQLite query from the render path.

That's the standard: a device, a Release build, two numbers per fix, the cause named, and the right-axis sentence. Anyone reading it can reproduce your measurement and verify your claim — which is the whole point of "measured, not guessed."

---

## Acceptance criteria

- [ ] The app is **deployed to a physical device** in a **Release** build (signing succeeded).
- [ ] A **Time Profiler** baseline capture identifies the heaviest main-thread work.
- [ ] **At least one main-thread hang** is found (Hangs instrument) and fixed by moving work off `@MainActor` (a `@ModelActor` for SwiftData), proven with before/after traces (hang count → 0).
- [ ] **At least one scroll hitch** is found (Animation Hitches) and fixed on the render path (prefetch / off-main decode / downsample), proven with before/after traces and a hitch-ratio number.
- [ ] `os_signpost` intervals mark the profiled operations.
- [ ] A **MetricKit collector** logs metric and diagnostic payloads (confirmed via Simulate MetricKit Payloads).
- [ ] `PERF.md` documents every fix as a before/after number on the named device.
- [ ] All fixes use real off-main concurrency — **no** suppressed Swift 6 concurrency warnings, **no** "made the slow thing faster" non-fixes.
- [ ] Build with **0 warnings, 0 errors**.

## Stretch goals

- **App Launch profiling.** Profile cold launch with the App Launch instrument; find post-main work you can defer (a big seed, an eager fetch in `init`) and cut launch time. Record the before/after.
- **CloudKit-merge hang hunt.** If you have CloudKit sync (Week 14), profile during a heavy sync import and find/fix any main-thread contention from the merge + `@Query` re-fetch.
- **The SwiftUI instrument.** Use the SwiftUI template to find a row whose `body` over-recomputes (too-coarse observation), narrow the observed state, and show the evaluation count drop.
- **Forward to the backend.** Actually POST `jsonRepresentation()` to a local Vapor endpoint and store it, prototyping the Phase IV telemetry pipeline.

## What this milestone earns you

You can now run an Instruments capture, read a flame graph, and ship a *measured* performance fix on a real device — the literal "skill earned" line for the week. More than that: you closed the measure-fix-measure loop on a real app, expressed every claim as a before/after number, and wired the telemetry that keeps the app honest in the field. Week 16 keeps the app on the device and adds the other axis of quality — accessibility — audited the same way: with a tool, fixed measurably, not asserted. You've made it fast and proven it; next you make it usable by everyone.
