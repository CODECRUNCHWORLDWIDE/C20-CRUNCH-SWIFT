# Week 21 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 22. Answer key with explanations at the bottom — don't peek.

---

**Q1.** Which is the clearest distinction between a Widget and a Live Activity?

- A) Widgets are colourful; Live Activities are monochrome.
- B) A Widget refreshes on a budgeted timeline (minutes-to-hours); a Live Activity shows one ongoing *event*, updates in seconds, and is driven by a push to a token.
- C) A Live Activity can't appear on the Lock Screen.
- D) They are the same thing with different names.

---

**Q2.** In an `ActivityAttributes`, what belongs in the static attributes vs the nested `ContentState`?

- A) Everything goes in `ContentState`.
- B) The static attributes hold fixed identity (e.g. `noteID`, `noteTitle`); `ContentState` holds the dynamic, updatable values (e.g. elapsed time, a live counter).
- C) Static attributes hold the changing values; `ContentState` is fixed.
- D) The split is arbitrary.

---

**Q3.** You want a Live Activity to update while the app is **terminated**. What must you do?

- A) Call `activity.update(_:)` on a timer.
- B) Request the activity with `pushType: .token`, observe `pushTokenUpdates`, send the token to your backend, and have the backend push updates over APNs.
- C) Use a `BGAppRefreshTask` to update it.
- D) Nothing; Live Activities update themselves.

---

**Q4.** A Live Activity APNs push must use which topic and push-type?

- A) Topic `<bundle-id>`, push-type `alert`.
- B) Topic `<bundle-id>.push-type.liveactivity`, header `apns-push-type: liveactivity`.
- C) Topic `<bundle-id>.liveactivity`, push-type `background`.
- D) Any topic works.

---

**Q5.** Your push is accepted by APNs (200) but the Lock Screen doesn't change. What's the most likely cause?

- A) The device is offline.
- B) The `content-state` JSON doesn't match your `ContentState` exactly (a misnamed key, or a `Date` sent as a string instead of a seconds number), so the decode silently fails.
- C) The activity expired.
- D) `apns-priority` was too low.

---

**Q6.** Why use `Text(date, style: .timer)` for the elapsed time instead of pushing a new number every second?

- A) It looks nicer.
- B) The `.timer` style is ticked by the system locally — it costs zero pushes; pushing every second would blow the budget and is unnecessary.
- C) It's required for the Dynamic Island.
- D) Pushed numbers can't be displayed.

---

**Q7.** What is **push-to-start** (iOS 17.2+) for?

- A) Restarting a crashed app.
- B) Letting the backend *create* a Live Activity (with `event: "start"`, `attributes-type`, `attributes`) on a terminated app, sent to the app-wide `pushToStartTokenUpdates` token.
- C) Starting the app from a widget.
- D) A faster `Activity.request`.

---

**Q8.** Which background task is right for "pull the latest notes and reload the widget," and which for "re-index the entire Spotlight catalogue when idle and charging"?

- A) Both use `BGProcessingTask`.
- B) `BGAppRefreshTask` for the short freshness pull; `BGProcessingTask` (with `requiresExternalPower`) for the long idle-time re-index.
- C) Both use `BGAppRefreshTask`.
- D) Background tasks can't reload widgets.

---

**Q9.** Your `BGAppRefreshTask` fires once and never again. What did you forget?

- A) To set an `earliestBeginDate`.
- B) To call `scheduleRefresh()` (submit the next request) from *inside* the handler — background tasks don't auto-repeat.
- C) To register the handler.
- D) To complete the task.

---

**Q10.** What happens if your background handler ignores `task.expirationHandler` and overruns its time budget?

- A) Nothing; the task just finishes late.
- B) iOS kills the app, which counts against you and trains the scheduler to run you less often.
- C) The task is automatically retried.
- D) The widget reloads twice.

---

**Q11.** A task identifier you registered isn't listed in `BGTaskSchedulerPermittedIdentifiers`. What happens?

- A) It works anyway.
- B) `register(forTaskWithIdentifier:)` fails at runtime and the task never runs.
- C) Only the first run works.
- D) It runs but can't reload widgets.

---

**Q12.** How does **Low Power Mode** change this week's surfaces, and how should you respond?

- A) It has no effect on background work.
- B) Background refresh is curtailed and Live Activity pushes are deprioritised; you detect it (`isLowPowerModeEnabled`) and degrade gracefully — fewer/larger updates, longer stale dates, deferrable work deferred.
- C) You should disable the app entirely.
- D) It speeds everything up to finish before the battery dies.

---

**Q13.** Why must correctness never depend on a background task or a timely Live Activity push?

- A) They always run on time.
- B) The background *budget* runs tasks on the system's terms — `earliestBeginDate` is a floor, engagement buys budget, pushes are throttled under LPM/thermal pressure — so they're best-effort; make freshness depend on them and correctness survive without them.
- C) Because Apple charges per task.
- D) They only run on Wi-Fi.

---

## Answer key

**Q1 — B.** A Widget is a budgeted, timeline-driven glance (minutes-to-hours); a Live Activity is a seconds-granularity window onto one ongoing *event*, driven by a push to a token. They share view code and the extension but are different mechanisms. (Lecture 1, §1.)

**Q2 — B.** Static attributes hold fixed identity (`noteID`, `noteTitle`); `ContentState` holds the dynamic, updatable, `Codable`/`Hashable` values that travel in the push. A changing value in `attributes` can't be updated; a static value in `ContentState` bloats every push. (Lecture 1, §2.)

**Q3 — B.** Local `update` only works while the app runs. To update a terminated app's activity, request with `pushType: .token`, observe `pushTokenUpdates`, send the token to the backend, and push over APNs. (Lecture 1, §1; §5.)

**Q4 — B.** The topic must carry the `.push-type.liveactivity` suffix and the header must be `apns-push-type: liveactivity`; a normal-notification topic is rejected. (Lecture 1, §5; §7.)

**Q5 — B.** The most common silent failure: `content-state` keys/encoding don't match `ContentState` (especially `Date`, which must be a seconds-since-1970 number). The decode fails with no Lock Screen error. (Lecture 1, §5; exercise 2.)

**Q6 — B.** `Text(date, style: .timer)` is system-ticked locally — zero pushes for the clock. Pushing a number every second would exhaust the budget. (Lecture 1, §4.)

**Q7 — B.** Push-to-start lets the backend *create* an activity on a terminated app, via `event: "start"` with `attributes-type` and `attributes`, sent to the app-wide `pushToStartTokenUpdates` token. (Lecture 1, §6.)

**Q8 — B.** `BGAppRefreshTask` for short, frequent freshness; `BGProcessingTask` (optionally `requiresExternalPower`) for long, deferrable idle-time work. (Lecture 2, §1.)

**Q9 — B.** Background tasks don't auto-repeat. You must submit the next request from inside the handler (re-schedule at the top of the handler). (Lecture 2, §2; §6.)

**Q10 — B.** Ignoring the expiration handler and overrunning gets the app killed, which counts against you and trains the scheduler to run you less. Set a cancelling expiration handler and complete on time. (Lecture 2, §2; §6.)

**Q11 — B.** An identifier not in `BGTaskSchedulerPermittedIdentifiers` makes `register` fail at runtime and the task never runs. (Lecture 2, §2; §6.)

**Q12 — B.** LPM curtails background refresh and deprioritises Live Activity pushes. Detect it (`isLowPowerModeEnabled`, the power-state notification) and degrade gracefully — fewer/larger updates, forgiving stale dates, deferrable work deferred. (Lecture 2, §4.)

**Q13 — B.** The background budget is best-effort: `earliestBeginDate` is a floor, engagement buys budget, pushes are throttled under LPM/thermal pressure. Make freshness depend on them; make correctness survive without them. (Lecture 2, §5.)

---

*Score 11+? On to Week 22. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — the push-drives-the-terminated-activity idea and the background-task contract are the two ideas this week is graded on.*
