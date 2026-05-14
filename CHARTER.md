# C20 · Crunch Swift — Charter

> The design rationale for the track. Why iOS as a discipline, why 24 weeks, why we teach cross-platform Swift before SwiftUI, why our open-source defaults are what they are, and how this track relates to its Droid sibling.

This document is the source of truth for *why* C20 is shaped the way it is. The `SYLLABUS.md` is the *what* and *when*. When the two disagree, this charter wins — and the syllabus is the one we change.

---

## Why iOS as a discipline

iOS is the small-team highest-margin platform in modern software. A two-engineer iOS shop can build a product that earns a living for both. A two-engineer Android shop can too — but Android's revenue per user remains structurally lower in most categories, which means iOS teams more often get to choose craft over scale. That's not a moral fact about either platform; it's a market fact, and it shapes what working on iOS feels like day to day.

The platform also rewards craft in a way few others do. SwiftUI animations have curves. Haptics have intent. App Review is allergic to half-built. The cost of shipping a hitch on the Home Screen is visible. The cost of shipping an inaccessible app is reputational. An engineer who has spent two years inside Apple's stack learns a discipline that compounds across the rest of their career — they ship less, but what they ship lasts longer, runs cleaner, and reads better.

We teach iOS because we want graduates who can build the product that earns the rent and the reputation that earns the next job. We do not teach iOS to make Apple richer. We teach it because the engineering surface it offers is uniquely deep, and uniquely public.

---

## Why 24 weeks

iOS is not a 12-week subject. It is not a 15-week subject either. Apple has shipped, at the time of this charter:

- A general-purpose language with strict concurrency (Swift 6)
- A declarative UI framework with its own diffing model (SwiftUI)
- A modern persistence framework that wraps and replaces the previous one (SwiftData / Core Data)
- Two concurrency models (Combine and async/await) that still live side by side
- A cross-device sync system (CloudKit)
- A subscription system with server-side receipt validation (StoreKit 2)
- A push-notification system, a notification service extension, and a content extension surface (APNs, NSE, CSE)
- A widget framework, an app-intents framework, a live-activity framework, a background-task framework
- Six client platforms (iOS, iPadOS, macOS, watchOS, visionOS, tvOS)
- A submission pipeline that gatekeeps every public app on those platforms (App Review)

A 12-week track can survey this. It cannot teach it. A 24-week semester is the smallest window in which a cohort can move from "I have read about SwiftUI" to "I have shipped a multi-platform app to TestFlight in five regions and survived a chaos drill." Anything shorter produces engineers who can write SwiftUI demos. We are not in the SwiftUI-demo business.

The 24-week length also gives the cohort time to **wait for things to break** — to ship a build, watch it run on real devices for a week, and come back to fix what broke. Production engineering is mostly that loop. A shorter track does not have room for the loop.

---

## Topic ordering — why cross-platform Swift comes first

The first six weeks of this track use only the open-source Swift toolchain on Linux, building a Vapor HTTP service with strict concurrency. The next six introduce SwiftUI and SwiftData on a Mac. The next six are production iOS. The last six are multi-platform, ecosystem features, and the capstone.

This ordering is deliberate, and it is not the ordering Apple's own learning materials use.

**Reason one — admission.** A prospective student who lives in a country where a Mac costs three months' salary can do six weeks of real Swift work before deciding whether to acquire the hardware. We are not gatekeeping the language behind the price of a laptop. Pathway B in the Crunch Labs Charter says iOS is one of the two routes to senior mobile engineering; we mean it.

**Reason two — engineering hygiene.** Swift the language is more interesting than Swift-as-iOS-grammar. By teaching protocols, generics, opaque types, and strict concurrency before the cohort ever opens Xcode, we install the right mental model: SwiftUI is *built on top of* a typed, value-oriented, structured-concurrency language. Reverse the order and you get engineers who think SwiftUI *is* the language — and they ship code that fights both.

**Reason three — backend-first careers.** Several of our students will end up writing more Vapor than SwiftUI. Server-side Swift is a real, deployable surface — the Linkedin, Apple Music, and PointFree codebases include it — and we want graduates who can take it seriously. The Vapor weeks pay for themselves whether the student becomes an iOS engineer or a polyglot backend engineer.

**Reason four — production concerns last.** Persistence, performance, security, IAP, push, and App Review require maturity. A week-four student does not have it. A week-fourteen student does. We arrange the track so that the engineering surface gets harder as the cohort gets stronger, not the other way around.

---

## Open-source-first stance

The Crunch Labs Charter states that Crunch Labs teaches open-source paths first and vendor lock-in paths second. Apple's stack is the limit case of that policy: it is, for the iOS surface specifically, the only stack.

We respond to that constraint, not by ignoring it, but by being explicit:

- **Swift the language is open-source.** We start there. The compiler, the standard library, the Swift Package Manager, swift-nio, swift-collections, swift-log, swift-metrics, swift-distributed-tracing, swift-syntax, and the Swift Evolution process — all open, all teachable.
- **Vapor is open-source.** We pick Vapor over a proprietary backend so that the cohort owns the server they ship. Hummingbird is named as the alternative.
- **The Composable Architecture is open-source.** Point-Free's TCA is the architecture we teach next to plain SwiftUI MVVM. It is GPL-friendly, version-controlled in public, and used in production across many shipping apps.
- **OpenTelemetry-Swift over proprietary APM.** We instrument the Vapor backend with OpenTelemetry exporters, not with vendor SDKs. The cohort can ship traces to Jaeger, Honeycomb, or any compliant collector — their choice, not ours.
- **fastlane over proprietary build services.** Fastlane is open-source and GitHub-Actions-friendly. We teach it as the contract for iOS CI. Xcode Cloud is named and described, never required.
- **mitmproxy over Charles.** Wireshark and `tcpdump` over proprietary inspectors.

Where Apple's stack is the only path — SwiftUI, SwiftData, CloudKit, StoreKit, App Review, APNs — we teach it directly and we are honest about the lock-in. The student who finishes this track has the open-source skills to walk to Android, the server side, or another platform. They also have the Apple-specific skills to take the iOS job. Both are real, both are taught, both are named for what they are.

---

## Relationship to C21 (Crunch Droid)

C20 and C21 are siblings, not competitors. Pathway B in the Crunch Labs Charter routes a student through one of them — or, more often than people expect, through both in sequence.

**Where they overlap.** Architectural patterns (MVVM, unidirectional state, offline-first sync), networking discipline (typed clients, retry, jitter, certificate pinning), persistence reasoning (sandboxed file systems, key stores, sync conflict resolution), and CI discipline (build, test, snapshot, distribute) transfer directly between the two tracks. A student who finishes one will recognise 30–40% of the other.

**Where they diverge.** Every platform API. SwiftUI is not Compose. Swift is not Kotlin. CloudKit is not Firestore. StoreKit 2 is not Google Play Billing. APNs is not FCM. App Review is not Play Console review. The fluency you build in one stack does not transfer to the other — it merely *prepares you to learn* the other faster.

**We do not pretend Flutter, React Native, or Kotlin Multiplatform replace this.** Cross-platform frameworks have a legitimate place in early product validation and in resource-constrained teams. They do not, at the time of this charter, produce engineers who can debug a SwiftUI re-render storm, reason about Sendable across an actor boundary, or hold their own in a senior interview about iOS app launch performance. We name them in the syllabus and we respect them; we do not teach them here.

A graduate who wants the **full mobile-engineering profile** takes C20 and then C21 (or vice versa), in sequence, over roughly a year. A graduate who wants **iOS specifically** takes C20 alone. Both are correct paths.

---

## Vendor stance — what we will and will not endorse

We will use:

- Xcode (free; the only first-class Swift IDE)
- The iOS / iPadOS / macOS / watchOS / visionOS simulators (bundled with Xcode)
- The App Store Connect API (the only way to ship to the store programmatically)
- TestFlight (the only way to beta-test on iOS)
- APNs (the only push delivery system on iOS)
- StoreKit 2 (the only sanctioned IAP system on iOS)
- CloudKit (the only Apple-managed cross-device sync for the Apple ecosystem)

We will not endorse:

- The Apple Developer Program as a moral product. It is a $99 toll on shipping. We treat it as a line item.
- Apple's "we know best" curation as engineering wisdom. App Review's design judgements are theirs; the engineering judgement remains the engineer's.
- AppCode or other paid Swift IDEs over Xcode. Xcode is free and standard.
- Charles Proxy over open alternatives. mitmproxy, Proxyman free tier, or Wireshark cover the same surface.
- Closed-source telemetry SDKs as a default. OpenTelemetry-Swift first.

The cohort is told, repeatedly, that the Apple Developer Program is a paid subscription to Apple's distribution channel — not a credential. We do not teach credentialism. We teach engineering.

---

## A note on Swift the language

Swift is in a rare state for a corporate-backed language: it is *also* open-source, governed by an Evolution process, and is being adopted (slowly, carefully) for use on Linux servers and embedded targets. The same language that drives a Lock Screen widget drives a Vapor service on a Linux VPS. That single fact is why we start where we start.

Three of our six Phase I weeks use no Apple software at all. The cohort writes Swift on Linux containers, debugs with the open-source LLDB, packages with SwiftPM, and runs Swift Testing without ever opening Xcode. That experience matters. It says: **Swift the language is yours, not Apple's**.

This charter is content to teach Apple's frameworks. It is not willing to pretend Apple owns Swift. It does not.

---

## What happens after each WWDC

Apple ships a major OS release every September and a major Swift release roughly every year. The syllabus is therefore a *living document* with a stated revision policy:

1. After each June WWDC, the curriculum council reviews every week against the announced changes.
2. The syllabus is revved on a branch through July and August.
3. The new version freezes for the autumn cohort by 1 September.
4. The previous version is archived under `OLD/SYLLABUS-YYYY.md` and remains available to running cohorts.

Topics like "SwiftData", "Live Activities", and "Observation" each entered the syllabus the year after they shipped at WWDC. Topics like "VIPER as a primary architecture" left it. The track ages forward.

---

## Status

This charter is live as of **2026-05-13**. It is the first edition of the C20 track, drafted under the Crunch Labs Charter dated the same day.

Signed by the Code Crunch Club curriculum council. Open an issue on the master curriculum repository to propose amendments.

Licensed **GPL-3.0** along with the rest of the academy.
