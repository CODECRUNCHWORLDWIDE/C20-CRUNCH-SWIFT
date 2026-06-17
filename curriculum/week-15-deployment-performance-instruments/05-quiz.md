# Week 15 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 16. Answer key with explanations at the bottom — don't peek.

---

**Q1.** What does a **provisioning profile** bind together?

- A) Just the certificate and the app's bundle id.
- B) The App ID, the allowed signing certificates, the device UDIDs (for development profiles), and the authorized entitlements.
- C) Only the device UDIDs.
- D) The app's source code and its Info.plist.

---

**Q2.** "Provisioning profile doesn't support the App Groups capability." Which of the four pieces is wrong?

- A) The certificate has expired.
- B) The device isn't registered.
- C) The entitlement is claimed in the build but the App ID/profile don't grant it.
- D) The bundle id is invalid.

---

**Q3.** Why must performance measurements be taken on a physical device in a Release build, not the Simulator in Debug?

- A) The Simulator can't run SwiftUI.
- B) The Simulator runs on the Mac's faster CPU/memory and never throttles, and a Debug build is unoptimized — both mismeasure; only a Release build on the device tells the truth.
- C) Instruments doesn't work in the Simulator.
- D) Debug builds don't compile.

---

**Q4.** The UI is completely frozen — nothing responds — for about a second when you tap a button. What is this, and which instrument?

- A) A hitch; Animation Hitches.
- B) A memory leak; Leaks.
- C) A hang; the Hangs instrument (or Time Profiler on the main thread).
- D) A launch problem; App Launch.

---

**Q5.** A scroll *mostly* works but *stutters* during fast scrolling. What is this, and what's the usual cause?

- A) A hang; a synchronous network call.
- B) A hitch; expensive work (e.g. a synchronous image decode or a per-row fault) on the render-commit path blowing the frame budget.
- C) A leak; a retain cycle.
- D) A signing problem.

---

**Q6.** What is the per-frame budget at 60 Hz, and at 120 Hz (ProMotion)?

- A) 100 ms and 50 ms.
- B) 16.67 ms and 8.33 ms.
- C) 1 ms and 0.5 ms.
- D) There is no fixed budget.

---

**Q7.** In a Time Profiler flame graph, what's the difference between **self time** and **total time** for a function?

- A) They're the same.
- B) Self time is the function's own code; total time is the function plus everything it called. You follow total time down to a self-time spike to find the actual hot code.
- C) Self time includes callees; total time doesn't.
- D) Self time is on the main thread; total time is on background threads.

---

**Q8.** The Hangs instrument flags an interval and shows a synchronous `Data(contentsOf:)` on the main thread. What's the fix?

- A) Make the network faster.
- B) Move the work off the main actor (e.g. `await Task.detached { ... }` or a `@ModelActor` for SwiftData) and update the UI back on `@MainActor`.
- C) Add `@MainActor` to more functions.
- D) Disable the Hangs instrument.

---

**Q9.** What does an `OSSignposter` interval give you that the Time Profiler alone doesn't?

- A) Faster code.
- B) A named region for YOUR operation in the trace, correlated with the system tracks, so you can see "my load interval overlaps the hang the instrument flagged."
- C) Crash reports.
- D) Automatic optimization.

---

**Q10.** You navigate into and out of a screen ten times and persistent memory climbs each time, never coming back down. What's the likely cause and the tool?

- A) A hitch; Animation Hitches.
- B) A retain cycle (e.g. a closure capturing `self` strongly); Leaks + the Memory Graph to find what's keeping it alive.
- C) A hang; the Hangs instrument.
- D) Normal behaviour; no tool needed.

---

**Q11.** When do MetricKit `MXMetricPayload`s arrive?

- A) In real time, as events happen.
- B) Once per day, batched, delivered on a subsequent app launch — it's low-overhead field telemetry, not live profiling.
- C) Only when the app crashes.
- D) Only in the Simulator.

---

**Q12.** A SwiftUI list stutters and the SwiftUI instrument shows a row's `body` evaluating far more often than rows actually change. What's the cause and fix?

- A) Too many rows; use a `ForEach`.
- B) The row observes too coarsely (e.g. the whole `@Observable` store), so any store change re-runs every row; pass the specific leaf value so a row re-runs only when *its* data changes.
- C) The frame budget is too small; lower the refresh rate.
- D) A retain cycle; add `[weak self]`.

---

**Q13.** You "fixed" a hang by making the slow function 3× faster, and it still occasionally hangs under load. Why?

- A) The function is still too slow.
- B) Synchronous work on the main thread blocks the UI regardless of how fast it is — under load even "fast" work blows frames; the real fix is getting it OFF the main thread, not making it faster.
- C) The device is throttling.
- D) The build is Debug.

---

## Answer key

**Q1 — B.** The profile is the permission slip stapling App ID + certificates + device UDIDs + entitlements, embedded in the bundle and checked at launch. (Lecture 1, §2, §4.)

**Q2 — C.** An entitlement must be granted on the App ID and authorized by the profile; claiming one that isn't fails signing. The fix is to enable the capability in Signing & Capabilities, which updates all three pieces together. (Lecture 1, §3, §6, §7.)

**Q3 — B.** The Simulator runs on desktop silicon with no throttling, and Debug is unoptimized; both lie. Performance numbers come from a Release build on a physical device, full stop. (Lecture 1, §5; lecture 2, §6.6.)

**Q4 — C.** A frozen, unresponsive UI is a hang — the main thread blocked past the threshold. The Hangs instrument (or Time Profiler's main-thread track) finds the blocking work. (Lecture 2, §1, §3.)

**Q5 — B.** A stutter (not a freeze) during animation/scroll is a hitch — frames missing the budget because of work on the render-commit path. Animation Hitches measures it. (Lecture 2, §1, §4.)

**Q6 — B.** 16.67 ms at 60 Hz, 8.33 ms at 120 Hz. Half the budget on ProMotion, which is why a hitch invisible at 60 Hz shows at 120 Hz. (Lecture 2, §1, §4.)

**Q7 — B.** Self = own code; total = own + callees. Follow total down to the self-time spike to find the function actually burning CPU. (Lecture 2, §2.)

**Q8 — B.** A hang is work that belongs off `@MainActor` but isn't. Move it off-main (Task.detached, or a @ModelActor for SwiftData), `await`, update UI back on the main actor. (Lecture 2, §3; exercise 2.)

**Q9 — B.** Signposts put your named intervals in the trace, correlated with the system tracks — the bridge between your code and the profiler's view. (Lecture 2, §6; exercise 3.)

**Q10 — B.** Climbing persistent memory across navigation cycles is a leak, usually a retain cycle. Leaks finds it; the Memory Graph shows what keeps the object alive so you can `[weak self]` the cycle. (Lecture 2, §5.)

**Q11 — B.** Once per day, batched, on a later launch — low-overhead field telemetry by design. You use Instruments (live) for reproducible bugs and MetricKit (daily, aggregate) for the field. (Lecture 2, §7; exercise 3.)

**Q12 — B.** Over-recomputing `body` is usually too-coarse observation; pass the leaf value so a row re-runs only when its data changes. The SwiftUI instrument catches the over-evaluation. (Lecture 2, §6.5.)

**Q13 — B.** Synchronous main-thread work hangs the UI regardless of speed; under load even fast work blows frames. The fix is off-main, not faster. Optimizing speed is the wrong axis. (Lecture 2, §3; exercise 2.)

---

*Score 11+? On to Week 16. Below 9? Re-read both lecture notes and re-run exercises 1 and 2 — reading a flame graph and the hang-is-work-off-the-main-thread idea are the two ideas this week is graded on.*
