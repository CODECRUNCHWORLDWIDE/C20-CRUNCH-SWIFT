// Exercise 2 — Plant a main-thread hang, find it, fix it with structured concurrency
//
// Goal: Reproduce the single most common iOS performance bug — a synchronous slow
//       operation on the main thread that FREEZES the UI — find it in the Hangs
//       instrument (and the Time Profiler main-thread track), then move the work
//       off the main actor with structured concurrency so the UI stays responsive.
//       A hang is almost always "work that belongs off @MainActor but isn't."
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This file is a SwiftUI VIEW you drop into an app target (iOS 17+/macOS 14+).
// It has a "hang" button (the bug) and a "no-hang" button (the fix) so you can
// profile BOTH and compare. Profile on a PHYSICAL DEVICE in a RELEASE build.
//
//   1. Add this file to a SwiftUI app target; show `HangDemoView` as your root.
//   2. Run on the device (Release scheme).
//   3. Tap "Hang the UI (synchronous)" and notice the UI FREEZE — the spinner
//      stops, taps don't register — for the duration.
//   4. Profile (Cmd-I) with the Time Profiler or the SwiftUI/Hangs template, tap
//      the hang button, and find the synchronous work blocking the main thread.
//   5. Tap "Off-main (async)" and notice the UI STAYS RESPONSIVE while the same
//      work runs off the main actor.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] The synchronous button visibly FREEZES the UI on the device.
//   [ ] You located the blocking work in the Hangs instrument or the Time
//       Profiler's main-thread track.
//   [ ] The async button does the SAME work WITHOUT freezing the UI (the spinner
//       keeps spinning).
//   [ ] The fix uses real structured concurrency (off the main actor), NOT a
//       suppressed concurrency warning.
//   [ ] You can explain, in one sentence, why the first version hangs and the
//       second doesn't.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import SwiftUI

// ----------------------------------------------------------------------------
// The "work" — deliberately expensive and synchronous. In a real app this would
// be a big fetch, a file parse, an image batch decode, or a heavy computation.
// ----------------------------------------------------------------------------

enum HeavyWork {
    /// A CPU-bound computation that takes a visible fraction of a second.
    /// `nonisolated` so it can run off the main actor when we want it to.
    nonisolated static func crunch(rounds: Int = 8_000_000) -> Int {
        var acc = 0
        for i in 0..<rounds {
            acc = (acc &+ i &* 2_654_435_761) & 0x00FF_FFFF
        }
        return acc
    }
}

// ----------------------------------------------------------------------------
// The view: a spinner that's ALWAYS animating, so a frozen main thread is
// visible (the spinner stops). Two buttons: the bug and the fix.
// ----------------------------------------------------------------------------

struct HangDemoView: View {
    @State private var result = 0
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 32) {
            // This spinner FREEZES if the main thread is blocked — your hang detector.
            ProgressView()
                .scaleEffect(2)
                .padding(.bottom, 16)

            Text("Result: \(result)")
                .font(.system(.title2, design: .monospaced))

            // ----- THE BUG: synchronous work on the main thread -----
            Button("Hang the UI (synchronous)") {
                // This runs on @MainActor (the view's body/action context), so the
                // UI thread is BLOCKED until crunch() returns. The spinner freezes.
                result = HeavyWork.crunch()
            }
            .buttonStyle(.borderedProminent)

            // ----- THE FIX: same work, off the main actor -----
            Button("Off-main (async)") {
                Task { await runOffMain() }
            }
            .buttonStyle(.bordered)
            .disabled(isWorking)

            if isWorking { Text("working off-main…").foregroundStyle(.secondary) }
        }
        .padding()
    }

    /// Run the heavy work OFF the main actor; only the small result hops back on.
    @MainActor
    private func runOffMain() async {
        isWorking = true
        defer { isWorking = false }
        // Task.detached runs on a background executor; crunch() is `nonisolated`,
        // so it can. The `await` keeps the main thread free to draw frames — the
        // spinner keeps spinning. Only the Int result crosses back to @MainActor.
        let value = await Task.detached(priority: .userInitiated) {
            HeavyWork.crunch()
        }.value
        result = value           // back on @MainActor automatically
    }
}

#Preview { HangDemoView() }

// ----------------------------------------------------------------------------
// WHY the first hangs and the second doesn't (write it before reading):
//
//   A SwiftUI Button action runs on the main actor (the UI thread). The
//   synchronous `crunch()` therefore occupies the main thread until it returns,
//   so the run loop can't service touches or draw frames — the UI is frozen
//   (a hang). The async version moves `crunch()` onto a background executor via
//   Task.detached and `await`s it, leaving the main thread free to keep drawing
//   (the spinner keeps spinning); only the tiny Int result returns to the main
//   actor. Same work, but it's no longer ON the UI thread.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - If `crunch()` is too fast to freeze visibly on your device, raise `rounds`
//   until the synchronous button clearly stalls the spinner for ~0.5–1s. If it's
//   so slow the OS kills the app, lower it.
//
// - `nonisolated static func` is what lets `crunch()` run off the main actor. If
//   you mark it `@MainActor` (or it captures main-actor state), Task.detached
//   can't move it off-main and you'll get a concurrency warning — fix it by
//   making the work genuinely isolation-free, NOT by suppressing the warning.
//
// - In the Hangs instrument, the flagged interval's stack shows `crunch` on the
//   main thread for the synchronous button, and NOTHING on the main thread for
//   the async one (the work is on a background thread). That contrast IS the
//   lesson.
//
// - Don't "fix" the hang by making `crunch` faster — that's optimizing the wrong
//   axis. Even fast work blocks the UI if it's synchronous on the main thread
//   under load. The fix is getting it OFF the main thread.
//
// - For a SwiftData version of this (a big fetch hanging the UI), the off-main
//   pattern is a @ModelActor (Week 10) instead of Task.detached, because a
//   ModelContext isn't Sendable. Same principle, different mechanism.
//
// ----------------------------------------------------------------------------
