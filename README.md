# C20 · Crunch Swift — iOS & Apple Platform Engineering

> Code Crunch Club · Crunch Labs tier · sub-brand **Swift** (`#F05138`)
> 24 weeks · ~864 hours · GPL-3.0
> Track home: `C20-CRUNCH-SWIFT/`

Twenty-four weeks to walk from "I can read a typed OOP language" to "I ship production iOS apps the senior engineer in the room defers to on." We start where anyone can start — Swift the open-source language, on Linux, building a Vapor HTTP service with structured concurrency — and we end with a multi-platform SwiftUI + SwiftData app that syncs over CloudKit, monetises with StoreKit 2, runs Live Activities under load, and clears App Review on the first submission. Along the way you will write Swift 6 with strict concurrency, debug a hitch in Instruments, instrument a hang in production, rotate an APNs auth key, prove a subscription renewal with a signed receipt, and ship a TestFlight build to five regions.

This is not a "build a to-do app in an afternoon" course. It is the curriculum we wish existed for engineers who want to take Apple-platform development seriously — including the bits about strict concurrency, offline-first sync, and what App Review actually rejects.

---

## Who this is for

Four personas, all welcome, all stretched:

1. **The Python or JavaScript engineer going native.** You ship Django, FastAPI, Rails, or Node every day. You want to move into native iOS without losing the engineering discipline you already have. We start you on Swift on Linux so you can move fast before you adopt the Mac-only parts of the toolchain.
2. **The UI/UX-minded engineer.** You finished C8 (Web Dev) and you love designing interfaces. You want a typed, declarative UI system with first-class animation, gesture, and accessibility primitives. SwiftUI is that system, and we teach it from layout-system internals up, not from drag-and-drop down.
3. **The cross-platform mobile developer wanting iOS depth.** You ship Flutter, React Native, or Kotlin Multiplatform today. You can build features. You cannot yet hold your own in a senior iOS interview about navigation state restoration, structured concurrency, or the SwiftUI diff algorithm. This track fixes that.
4. **The senior backend engineer building a client to their own service.** You run the API. Now you want the iOS client to be as well-engineered as the server. You need Vapor for the server-side Swift bridge, shared codable types, and a SwiftUI client that handles offline, retry, and conflict resolution with the same rigour you apply to your database.

If you have shipped one non-trivial product in a typed OOP language (Java, Kotlin, C#, TypeScript, Go, Rust, modern C++, or Swift itself), you are ready. If you have not, take C1 (Convos) and then C8 (Web Dev) first.

---

## What you will be able to do at the end

Twelve concrete capabilities you should have on day 168:

1. Write Swift 6 with **strict concurrency** enabled — explain `Sendable`, actor isolation, `MainActor`, `@isolated(any)`, structured task cancellation, and `AsyncSequence` back-pressure.
2. Design a SwiftUI screen from the layout system up — explain the `Layout` protocol, how `body` is diffed, when `@State` vs `@Observable` vs `@Environment` vs `@Bindable` is correct, and how to debug a runaway re-render.
3. Model an offline-first data layer with **SwiftData**, sync to CloudKit, and resolve a multi-device edit conflict deterministically.
4. Move between **Combine** and `async/await` + `AsyncSequence` fluently — and explain which to reach for in which decade.
5. Build a navigation graph with `NavigationStack` and `NavigationSplitView` that survives state restoration, deep links, and universal links across iPhone, iPad, and Mac.
6. Ship a URLSession networking stack with structured concurrency, typed errors, retry-with-jitter, request signing, and certificate pinning.
7. Implement an **MVVM** layer for one feature, **TCA** (The Composable Architecture) for another, and articulate why VIPER is no longer the right answer.
8. Diagnose a hitch, a hang, and a memory leak with **Instruments** — Time Profiler, Hangs, Memory Graph, Allocations — and ship a fix backed by a flame graph.
9. Stand up an iOS CI pipeline on GitHub Actions with `xcodebuild`, `xcbeautify`, Swift Testing + XCTest, snapshot tests, and a fastlane lane that uploads to TestFlight via the App Store Connect API.
10. Ship a feature that uses **WidgetKit**, **App Intents** (Shortcuts + Siri), **ActivityKit** (Live Activities), and a **Background Task** — and prove they work under low-power mode.
11. Implement a **StoreKit 2** subscription with auto-renew, family sharing, restore-purchase, server-side receipt validation against a Vapor backend, and full subscription-edge-case coverage (refund, downgrade, billing retry).
12. Submit an app to App Review, pass on the first attempt, and instrument the live build with **MetricKit**, crash symbolication, and a feature-flag killswitch you can flip from the Vapor admin console.

---

## Prerequisites

| Required | Helpful | Not required |
| --- | --- | --- |
| **C1 — Code Crunch Convos** (or equivalent typed-OOP fluency) | **C8 — Web Dev** (declarative UI mental model) | A four-year CS degree |
| Comfort with at least one typed OOP language | Some prior mobile or front-end experience | A previous iOS job |
| A laptop (Linux or any OS for weeks 1–6) | An Apple Developer account ($99/yr, only needed in Phase 3) | An Apple Developer account at enrolment |

**Hardware reality.** Weeks 1–6 (Swift the language + Vapor server-side) run on **Linux, macOS, or Windows + WSL2** — open-source Swift toolchain only. From week 7 onward you need a **Mac (Apple Silicon strongly recommended — M1 or newer)** with **Xcode 16+** installed (free from the Mac App Store). Phases 1 and 2 use the iOS Simulator, which is bundled with Xcode and free.

**When the $99 developer membership matters.** Not until Phase 3, week 15, when we deploy to a physical iPhone or iPad for device-only feature testing (camera, ARKit, BLE, Live Activities on a Lock Screen, push notifications to a real device). Phase 4 requires it for TestFlight and App Review. We give two weeks of lead time so you can buy it when the schedule actually demands it, not on day 1.

---

## Program at a glance — four phases

| Phase | Weeks | Title | Focus | Capstone milestone |
| --- | --- | --- | --- | --- |
| I | 1–6 | Foundations | Swift the language, server-side Swift, Vapor, strict concurrency | Vapor JSON service with shared codable types, deployable to Linux |
| II | 7–12 | SwiftUI & State Management | SwiftUI layout, state, navigation, SwiftData, app architecture | Offline-first SwiftUI notes app with SwiftData persistence |
| III | 13–18 | Production iOS | Networking, persistence, perf, accessibility, security, IAP, push | iOS app with StoreKit 2, APNs, MetricKit, Instruments-tuned |
| IV | 19–24 | Capstone & Polish | Multi-platform, App Intents, Widgets, Live Activities, App Review | Cross-device productivity suite shipped to TestFlight in 5 regions |

Week-by-week detail lives in [`SYLLABUS.md`](./SYLLABUS.md). Design rationale (why 24 weeks, why cross-platform Swift first, why production concerns last) lives in [`CHARTER.md`](./CHARTER.md).

---

## Weekly cadence

The track runs at **36 hours per week** for full-time cohorts and compresses to **12 hours per week** for self-paced cohorts. Each week ships one mini-project, one quiz, and one logged build-and-profile entry.

| Day | Block | Typical content |
| --- | --- | --- |
| Mon | Lecture (2h) | Topic intro, reference reading, framework-source-code walkthrough |
| Mon | Lab (3h) | Guided exercise — write the code, run the tests, profile the result |
| Wed | Lecture (2h) | Deeper dive, code review of last week's lab, architecture decision record |
| Wed | Lab (3h) | Open-ended mini-project sprint |
| Fri | Studio (4h) | Instruments clinic, App Review prep, code-review office hours, simulator debugging |
| Sun | Quiz (~30m) + reading | Auto-graded; covers framework docs, WWDC notes, and the week's reading list |

The remaining ~22 hours are unstructured project time — building, breaking, and shipping.

---

## Hardware, software, and license expectations

- **Mac with Apple Silicon recommended.** M1 / M2 / M3 / M4 Air or Pro. Intel Macs work for most of Phase 2 but get punishing in Phase 3 (simulator boot, Instruments capture, Xcode build times). 16 GB RAM is the realistic minimum; 24+ GB is comfortable.
- **Xcode 16 or newer** (free). Includes Swift compiler, the iOS / iPadOS / macOS / watchOS / visionOS simulators, Instruments, and the App Store Connect submission tooling.
- **Swift toolchain on Linux for weeks 1–6.** Use the official `swift.org` Docker image or apt packages on Ubuntu 22.04 / 24.04. Cross-platform Swift means you can do six weeks of real work without Apple's stack.
- **An iPhone or iPad** (any model from the last five years) for week 15 onward. A used iPhone is acceptable; the simulator is fine for everything except camera, ARKit, BLE, real-device push, and Live Activities on a physical Lock Screen.
- **Apple Developer Program membership ($99/yr)** at week 15. Required for device deployment, TestFlight, and App Store submission.
- **No proprietary IDE plugins required.** We do not require AppCode, Tower, Charles Proxy, or any paid tool. Open-source equivalents are taught first (`mitmproxy` over Charles, `git` CLI over Tower).

---

## Recommended pre/post tracks

```text
C1 (Code Crunch Convos · Python)
        |
        v
C8 (Crunch Labs — Web Dev)        <-- recommended for SwiftUI mental model
        |
        v
*** C20 (Crunch Swift — iOS & Apple Platform Engineering) ***
        |
        +--> C16 / C17  (Crunch Pro — Web Backend / Python Advanced)
        |       for a polyglot full-stack profile
        |
        +--> C18 / C19  (Crunch GCP / AWS)
        |       to operate the Vapor backend at fleet scale
        |
        +--> C21 (Crunch Droid)
                to cover Android with the same rigour
```

- **C20 vs C21.** C20 owns Swift, SwiftUI, and the Apple platforms. C21 owns Kotlin, Jetpack Compose, and Android. They overlap on architectural patterns (MVVM, unidirectional state, offline-first sync) and diverge on every platform API. Taking both is **Pathway B — Mobile Engineering** in the Crunch Labs Charter; many graduates do, in sequence, not in parallel.
- **C20 to C16 / C17.** The Vapor backend in this track is competent but minimal. C16 (Web Backend) and C17 (Python Advanced) deepen the server side if your capstone makes you want to own both halves of the stack.
- **C20 to C18 / C19.** If your capstone TestFlight beta scales beyond a single Vapor box, take a cloud track to learn how to host, observe, and on-call the backend properly.

---

## What this course will NOT do

Honest expectations, set up front:

- **It will not make you a designer.** We respect design — we teach the SF Symbols catalog, the Human Interface Guidelines, Dynamic Type, and the SwiftUI animation model — but we do not teach Figma, brand systems, or product strategy. Pair with a designer for the capstone if you can.
- **It will not pretend cross-platform frameworks are equivalent to native.** Flutter, React Native, and Kotlin Multiplatform have a place. They do not replace the depth you need to debug a SwiftUI re-render storm or reason about Sendable across an actor boundary. We name them, we respect them, we do not teach them here.
- **It will not lock you into Apple.** Swift the language is open-source. The Vapor weeks run on Linux. We use open SwiftPM packages over private SDKs wherever an open path exists. Where Apple's stack is the only path (SwiftUI, SwiftData, CloudKit, StoreKit, App Review), we are explicit about the trade.
- **It will not get your app featured on the App Store.** We will teach you what App Review checks for, how to write metadata, and how to design screenshots that read at 1x — but editorial features depend on judgement that no curriculum can guarantee.
- **It will not certify you as an Apple engineer.** Apple does not certify engineers. We give you a portfolio of three deployed apps, a TestFlight history, a runbook, and an interview-prep pack — the closest equivalent in the actual job market.

---

## Capstone preview

The Phase 4 capstone is **one substantial cross-device system**, not a parade of small apps:

> **Offline-First Cross-Device Productivity Suite.** SwiftUI app for iPhone, iPad, and Mac, with a watchOS companion and a visionOS view. Persists with SwiftData, syncs over CloudKit, and falls back to a Vapor REST + WebSocket backend when CloudKit is unavailable. Exposes App Intents to Shortcuts and Siri. Renders Widgets on the Home Screen and Lock Screen. Drives a Live Activity from a real-time event. Monetises with a StoreKit 2 subscription validated against the Vapor backend. Ships to TestFlight in five regions and survives a one-week beta cohort, an offline-edit-conflict chaos drill, and an APNs auth-key rotation drill.

Full specification in [`SYLLABUS.md` § Capstone](./SYLLABUS.md#capstone). Deliverables include an architecture diagram, a five-minute video walkthrough, a chaos-drill postmortem, and a production runbook.

---

## License & maintainers

Licensed **GPL-3.0**. See [`LICENSE`](./LICENSE).

Maintained by the Code Crunch Club curriculum council. Open an issue on the master curriculum repository to propose curriculum changes, donate hardware, or contribute lecture notes. Contributions follow the repository-wide `CONTRIBUTING.md`.

This is a living document. iOS, SwiftUI, and Swift the language each ship a major release every year. We rev the syllabus after every June WWDC and freeze it for the following academic cohort by August.
