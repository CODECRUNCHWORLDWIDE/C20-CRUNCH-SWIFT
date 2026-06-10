# Week 15 — On-device deployment, performance with Instruments

Welcome to Week 15 of **C20 · Crunch Swift**. For fourteen weeks you have run everything in the Simulator. This week the app leaves the Mac and runs on a **physical iPhone or iPad** — and that is not a formality. The Simulator runs your code on a desktop-class CPU with desktop memory bandwidth; it lies about performance. A list that scrolls at 120 fps in the Simulator can hitch on a real A-series device with a thermal budget and a slower GPU. A view body that recomputes too often is invisible on an M-series Mac and a frame-dropping disaster on a three-year-old iPhone. The whole point of going on-device is that **the device tells the truth**, and the tool that reads that truth is **Instruments**.

> **This is the week the Apple Developer Program membership becomes required.** You cannot deploy to a physical device, or profile a release build on one, without a signed provisioning profile, which needs the $99/year membership. We told you in Week 14 to buy it; if you haven't, do it now — this week needs it on day one.

This week has two halves that depend on each other. The first half is **deployment**: code signing, provisioning profiles, the dance of certificate + identifier + profile that lets your build run on a device you own. This is the part everyone finds baffling the first time, and the baffling-ness is not your fault — it's a genuinely intricate PKI system. We demystify it: a *certificate* proves *you* are a registered developer, a *provisioning profile* binds *your app id* + *your certificate* + *a set of device UDIDs* into a permission slip the device checks at launch, and Xcode's "Automatically manage signing" hides most of it until it breaks, at which point you need to know what's underneath. The second half is **performance**: once the app is on the device, you profile it with Instruments — **Time Profiler** for where the CPU goes, **Hangs** for the main-thread stalls that freeze the UI, **Hitches** for the dropped frames in a scroll, **Allocations** and **Leaks** and the **Memory Graph** for memory problems, and **`os_signpost`** to mark your own intervals in the trace. You will diagnose a real hang and a real hitch in Notes v1, fix them, and *prove* the fix with a before/after trace.

The mental shift this week is from "it feels fast" to "I measured it, here's the flame graph, here's the fix, here's the after-trace." A junior engineer optimizes by guessing — rewriting a loop they *think* is slow. A senior engineer **profiles first**, because the slow thing is almost never the thing you'd guess; it's a main-thread Core Data fault inside a `body`, or an image decode on the scroll path, or a layout pass triggered by a state write you didn't know happened. The discipline this week earns is *measure, then fix, then measure again* — and the vocabulary to say exactly which Instrument reads which problem, because reaching for the Allocations instrument to diagnose a hang is like using a thermometer to measure distance.

We close the week by profiling Notes v1 on a real device. You will run the **Time Profiler** while scrolling the notes list and find at least one **main-thread hang** (a synchronous operation blocking the UI thread past the hang threshold) and one **hitch** (a frame that missed the 16.67 ms budget mid-scroll), fix both, and re-profile to show the hang is gone and the hitch budget is met. You will also ship a **MetricKit** collector that receives the daily diagnostic and metric payloads the OS delivers — so that once the app is in users' hands, you have field data on hangs, launches, and crashes, not just what you saw on your one device.

## Learning objectives

By the end of this week, you will be able to:

- **Deploy** a build to a physical device you own — register the device, create or let Xcode manage a development certificate and provisioning profile, resolve the common signing errors, and run on-device.
- **Explain** the code-signing model: what a certificate, an app id, a provisioning profile, and an entitlement each are, how they combine, and what "Automatically manage signing" does and hides.
- **Choose the right Instrument** for each problem — Time Profiler for CPU, Hangs for main-thread stalls, Hitches/Animation Hitches for dropped frames, Allocations for memory growth, Leaks for retain cycles, the Memory Graph for "what's keeping this alive," App Launch for cold-start cost, and the SwiftUI instrument for view-body cost.
- **Read a flame graph** — heaviest stack, self vs total time, the main-thread track — and locate the exact function responsible for a CPU cost.
- **Diagnose a main-thread hang**: identify a synchronous operation blocking the UI thread past the hang threshold, find it in the Hangs instrument, and move it off the main thread.
- **Diagnose a hitch**: understand the **16.67 ms** frame budget (60 Hz) and **8.33 ms** (120 Hz ProMotion), find a frame that missed it in the Hitches instrument, and fix the work on the render commit path.
- **Instrument your own code** with `os_signpost` / `OSSignposter` intervals so your operations appear as named regions in the trace, correlated with the system tracks.
- **Collect field telemetry** with **MetricKit**: register an `MXMetricManagerSubscriber`, receive `MXMetricPayload` (hangs, launches, memory, disk) and `MXDiagnosticPayload` (crashes, hangs, CPU exceptions), and log/forward them.
- **Prove a fix** with a before/after trace, expressed as a number (hang count, hitch ratio, ms saved), not a vibe.

## Prerequisites

This week assumes you have completed **C20 weeks 1–14**, or have equivalent fluency. Specifically:

- You understand `Sendable`, `@MainActor`, actor isolation, and structured concurrency — Week 4. A hang is almost always work that should be off `@MainActor` but isn't; the fix is the concurrency you already know.
- You can model and query a SwiftData store and you know the **N+1 fault** and the **main-thread-write** footguns — Week 10. Those footguns are exactly the hangs and hitches you'll find in the profiler this week; Week 10 named them, Week 15 makes you find them with Instruments.
- You can build a SwiftUI view and reason about when `body` recomputes — Week 8. A hitch is often an over-recomputing `body` doing work on the render path; you need to know what triggers a re-render to fix it.
- You have **Notes v1** (with the Week 14 Keychain + CloudKit work, or at least the Week 10/13 version) checked into Git. This week's mini-project profiles it on a device; CloudKit sync merges are a prime hang suspect.
- **You have a paid Apple Developer membership and a physical iPhone or iPad** (any model from the last ~5 years). The membership is required this week; the device is required for the honest measurements.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), Instruments (bundled with Xcode), a physical iOS 17+/18 device, and a paid Apple Developer account. Profiling is done on a **Release** (or at least optimized) build on the device — never the Simulator and never a Debug build for performance numbers, because both lie about cost.

## Topics covered

- **Code signing, end to end.** The signing identity (certificate + private key in your Keychain), the App ID, the provisioning profile (App ID + certificates + device UDIDs + entitlements), and how the device verifies the signature at launch. Development vs distribution profiles.
- **Automatic vs manual signing.** What "Automatically manage signing" does (creates a development cert, a wildcard or explicit App ID, and a profile, and re-signs on every build), when it's enough, and the manual fallback when it isn't (shared team certs, CI, specific entitlements).
- **Device deployment.** Registering a device, trusting the developer certificate on the device, the "Untrusted Developer" prompt, the seven-day free-account limit (irrelevant now you're paid), and running and debugging on-device from Xcode.
- **The performance mental model.** The 16.67 ms (60 Hz) and 8.33 ms (120 Hz) frame budgets; the render loop (commit → render → display); the main thread as the UI thread; what a *hang*, a *hitch*, and a *leak* each are and why they're different problems.
- **Time Profiler.** Sampling the call stack on a timer; reading the flame graph / call tree; self time vs total time; "Heaviest Stack Trace"; charging cost to a function; the main-thread track vs background tracks.
- **Hangs instrument.** The hang threshold; micro-hangs vs severe hangs; finding the synchronous main-thread work that caused the stall; the connection to `@MainActor` and structured concurrency.
- **Hitches.** The Animation Hitches instrument; hitch time ratio; the render-commit deadline; what work on the scroll path (image decode, layout, Core Data fault) blows the frame budget; fixing by deferring or moving work off the commit path.
- **Allocations, Leaks, and the Memory Graph.** Persistent vs transient allocations; abandoned memory; a retain cycle in a closure capturing `self`; using the Memory Graph debugger to find what's keeping an object alive.
- **App Launch instrument.** Cold vs warm launch; pre-main vs post-main time; what bloats launch (dyld, static initializers, doing work in `init`/`onAppear` that should be deferred).
- **`os_signpost` / `OSSignposter`.** Marking intervals and events in your own code so they appear as regions in any Instruments trace, correlated with the system tracks — the bridge between "my code" and "the profiler's view."
- **MetricKit.** `MXMetricManager`, `MXMetricManagerSubscriber`, `MXMetricPayload` (hang rate, launch time, memory, disk writes, scroll hitch rate), `MXDiagnosticPayload` (crash, hang, CPU-exception, disk-write-exception diagnostics), and the daily delivery model.
- **Performance footguns.** Profiling the Simulator or a Debug build; optimizing without measuring; a synchronous file/network/Core-Data call on the main thread; an image decoded on the scroll path; a retain cycle in a closure; doing setup work in `body`.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                                 | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|-----------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Code signing + provisioning; deploy to a real device; signing errors  |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | The perf model; Time Profiler; reading a flame graph; `os_signpost`   |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Hangs + Hitches + the frame budget; Allocations/Leaks/Memory Graph    |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | MetricKit; App Launch; the measure-fix-measure loop; challenge        |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — profile Notes v1 on-device; fix a hang and a hitch     |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; before/after traces; MetricKit collector      |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                            |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                       | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Apple's code-signing guide, the Instruments docs, the WWDC performance sessions (hitches, hangs, MetricKit), and the canonical community writing on profiling SwiftUI |
| [lecture-notes/01-deployment-and-code-signing.md](./lecture-notes/01-deployment-and-code-signing.md) | Code signing demystified end to end — certificate, App ID, provisioning profile, entitlements, automatic vs manual signing, deploying to a device, and the common errors decoded |
| [lecture-notes/02-instruments-hangs-hitches-and-metrickit.md](./lecture-notes/02-instruments-hangs-hitches-and-metrickit.md) | The performance mental model, the frame budget, the right Instrument for each problem, reading a flame graph, `os_signpost`, and MetricKit field telemetry — with the measure-fix-measure loop |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-deploy-and-read-the-profile.md](./exercises/exercise-01-deploy-and-read-the-profile.md) | Deploy a build to your device, run the Time Profiler, and read a flame graph to locate the heaviest stack |
| [exercises/exercise-02-find-and-fix-a-hang.swift](./exercises/exercise-02-find-and-fix-a-hang.swift) | Plant a deliberate main-thread hang, find it in the Hangs instrument, move the work off-main with structured concurrency, and prove it's gone |
| [exercises/exercise-03-signposts-and-metrickit.swift](./exercises/exercise-03-signposts-and-metrickit.swift) | Instrument an operation with `OSSignposter`, see it in the trace, and wire a MetricKit subscriber that logs the daily payloads |
| [challenges/README.md](./challenges/README.md) | Index of the challenge |
| [challenges/challenge-01-hitch-then-fix.md](./challenges/challenge-01-hitch-then-fix.md) | Plant a scroll hitch (image decode on the render path), measure the hitch ratio in the Animation Hitches instrument, fix it, and document the before/after with traces |
| [quiz.md](./quiz.md) | 13 questions on code signing, the frame budget, the right Instrument per problem, hangs vs hitches vs leaks, signposts, and MetricKit |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for "Notes v1 — profiled on-device": deploy, find and fix a hang and a hitch, ship a MetricKit collector, prove it with traces |

## The "measured, not guessed" promise

Week 10 gave you "survives a cold launch." Week 14 gave you "the same on every device, no secret leaked." Week 15 adds the performance contract a senior reviewer actually checks:

> **Every performance claim is backed by a before/after trace and a number.** "I made the list scroll smoother" is not an engineering statement. "On an iPhone 13 release build, the notes-list scroll had a hitch ratio of 41 ms/s with two severe hangs from a main-thread CloudKit fault; after moving the fault off-main and prefetching the relationship, the hitch ratio is 3 ms/s with zero hangs — here are both traces" is. You will produce statements of the second kind.

You will *prove* it by capturing a trace on the device, fixing the cause, and capturing again — the hang count drops to zero, the hitch ratio drops below the budget. "It feels faster" is not the test; the trace is.

## A note on what's not here

Week 15 is the *deploy-and-profile* week. It deliberately does **not** cover:

- **CI and TestFlight distribution.** Getting a build onto *other people's* devices — `xcodebuild`, fastlane, the App Store Connect API, TestFlight — is Phase IV. This week is *your* device and *local* profiling. Distribution signing (the other half of the signing story) we name but don't drive.
- **GPU and Metal profiling.** The Metal System Trace, shader profiling, and the GPU-bound side of rendering are a specialist topic. We profile *CPU-bound* and *main-thread* problems — which is where ~95% of SwiftUI app performance bugs live — and name the GPU tools without diving in.
- **Crash symbolication at scale.** MetricKit delivers crash diagnostics, and we receive them; the full pipeline (dSYM upload, symbolication service, a crash dashboard) is Phase IV's production-telemetry work. This week you receive and log the payload; you don't stand up the backend that aggregates it.

The point of Week 15 is narrow and deep: get the app onto a real device honestly, pick the right Instrument for the problem in front of you, read the flame graph, fix the hang and the hitch, and prove it with a number.

## Up next

Continue to **Week 16 — Accessibility and inclusive engineering** once you have shipped this week's mini-project and proven a hang-and-hitch fix with traces. Week 16 keeps the app on the device and adds the other dimension of quality a senior reviewer checks: whether the app works for someone navigating with VoiceOver, reading at the largest Dynamic Type setting, or who has reduce-motion on. The profiling discipline carries over — accessibility, like performance, is something you *audit* with a tool (the Accessibility Inspector) and *fix measurably*, not something you assert. You now have a fast app on a real device; next you make it usable by everyone.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
