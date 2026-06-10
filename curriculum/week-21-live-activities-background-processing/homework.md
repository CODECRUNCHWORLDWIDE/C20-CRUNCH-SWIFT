# Week 21 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 21 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+ (iOS 17.2 for push-to-start), Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**. Problems marked **(device)** need a physical device for the push path; the rest run in the Simulator.

---

## Problem 1 — A second activity type: a focus timer

**Problem statement.** Define a `FocusTimerActivityAttributes` for a countdown focus session: static `sessionName`, dynamic `ContentState { endsAt: Date, isPaused: Bool }`. Render the Lock Screen and Dynamic Island so the remaining time counts down using `Text(timerInterval:)` / `Text(_, style: .timer)`, and start/end it locally.

**Acceptance criteria.**

- A correct static/dynamic split; `ContentState` is small, `Codable`, `Hashable`.
- The countdown uses a system-ticked timer text, not a value pushed each second.
- Start and end work locally; the activity dismisses cleanly.
- 0 warnings. Committed.

**Hint.** `Text(timerInterval: now...endsAt)` renders a live countdown. The `isPaused` flag lets you show a paused state without ticking.

**Estimated time.** 50 minutes.

---

## Problem 2 — Model the three payloads as Codable

**Problem statement.** Write `Encodable` Swift types that produce the exact JSON for the three Live Activity pushes: `start`, `update`, and `end`. Each must serialise `content-state` with the same keys as your `ContentState` and dates as seconds-since-1970 numbers. Write a small test that encodes each and asserts the JSON keys (`event`, `content-state`, `attributes-type`, `stale-date`, `dismissal-date`) are present and correct.

**Acceptance criteria.**

- Three `Encodable` payload types (or one with an `event` discriminator) producing valid JSON for start/update/end.
- `content-state` keys match `ContentState` exactly; dates are numbers.
- A passing test asserting the key names and structure.
- 0 warnings. Committed.

**Hint.** Use `CodingKeys` to map Swift camelCase to the hyphenated APNs keys (`content-state`, `stale-date`). Encode dates with `Int(date.timeIntervalSince1970)`.

**Estimated time.** 45 minutes.

---

## Problem 3 — Observe and persist the push token (device)

**Problem statement.** For your edit activity, observe `pushTokenUpdates` and **persist** the latest token (e.g. to the App Group `UserDefaults`), re-sending to a stub backend whenever it changes. Demonstrate that the token survives an app relaunch and that a rotation triggers a re-send.

**Acceptance criteria.**

- The activity is `pushType: .token`; `pushTokenUpdates` is observed as a full stream (not just the first value).
- The token is persisted and re-sent on every change.
- A documented demonstration (log lines / screenshots) of the token after relaunch and after a rotation.
- 0 warnings. Committed.

**Hint.** A rotation can be hard to force on demand; document the observation that you handle the *stream*, not one value, and show the re-send firing when the activity restarts with a new token.

**Estimated time.** 45 minutes.

---

## Problem 4 — A `BGProcessingTask` that re-indexes Spotlight

**Problem statement.** Add a `BGProcessingTask` (id listed in `Info.plist`) that re-indexes all notes into Core Spotlight (Week 20) when the device is idle and charging. Require external power, register the handler at launch, schedule it, and honour the expiration handler + exactly-once completion.

**Acceptance criteria.**

- The processing identifier is in `BGTaskSchedulerPermittedIdentifiers`; the handler is registered at launch.
- `BGProcessingTaskRequest` with `requiresExternalPower = true`; the handler re-schedules, sets a cancelling expiration handler, re-indexes, completes once.
- Fired with the LLDB simulate-launch trick and observed to run.
- 0 warnings. Committed.

**Hint.** Same contract as the app-refresh task (exercise 3) with a different request type. `requiresExternalPower` is what makes it "when charging." Re-indexing reuses your Week 20 `CSSearchableIndex` code.

**Estimated time.** 50 minutes.

---

## Problem 5 — Graceful degradation under Low Power Mode

**Problem statement.** Make your background refresh and your activity behaviour respond to Low Power Mode. Under LPM: the refresh pulls fewer rows, and the activity's `staleDate` is lengthened. Write `notes/low-power.md` documenting exactly what changes and the reasoning, and show the `isLowPowerModeEnabled` branch in code.

**Acceptance criteria.**

- The refresh work shrinks under LPM (e.g. 5 rows vs 50); the `staleDate` is longer under LPM.
- An observer on `.NSProcessInfoPowerStateDidChange` logs power-state changes.
- `notes/low-power.md` explains what degrades and why "acceptable at 14% battery" is the goal.
- 0 warnings. Committed.

**Hint.** Toggle Low Power Mode in the Simulator's Settings (or Features menu) to exercise the branch. `ProcessInfo.processInfo.isLowPowerModeEnabled` is the read; the notification is the change event.

**Estimated time.** 40 minutes.

---

## Problem 6 — End the activity cleanly from three angles

**Problem statement.** Implement three ways your edit activity can end correctly: (a) the user finishes editing (local `end` with a short linger), (b) the backend sends an `end` push (`event: "end"`, `isActive: false`, a `dismissal-date`), and (c) a safety timeout — if no update arrives for N minutes, the app ends a stale activity on next foreground. Document each and the `dismissalPolicy` you chose.

**Acceptance criteria.**

- All three end paths implemented; each uses a sensible `dismissalPolicy`.
- The backend `end` payload is correct (`event`, `isActive: false`, `dismissal-date`).
- The safety timeout ends activities older than N minutes on foreground (recover via `Activity.activities`).
- `notes/ending-activities.md` documents the three paths. 0 warnings. Committed.

**Hint.** For (c), on `scenePhase == .active`, iterate `Activity<NoteEditActivityAttributes>.activities`, check `content.state.startedAt` age, and `end` the stale ones. This prevents a "ghost" activity that never got its `end` push.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/ActivityKit/BackgroundTasks, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a too-tight stale date, a pushed timer where `.timer` style was the point). |
| 3 | Works, but misses one criterion (e.g. observes only the first push token, background task not re-scheduled, `content-state` keys slightly off). |
| 2 | Compiles and partially works; a core idea is wrong (local update where a push was required; background handler never completes). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any suppressed Swift 6 concurrency warning used to silence the compiler instead of restructuring; **−2** for a background handler that can fail to call `setTaskCompleted` on some path; **−1** for a `content-state` whose keys don't match `ContentState`, or a `Date` encoded as a string instead of a seconds number.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the push that drives a terminated activity (problems 2, 3, 6) and the background-task contract (problems 4, 5) — so re-run exercises 02 and 03 before resubmitting.
