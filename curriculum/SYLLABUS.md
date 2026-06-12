# C20 · Crunch Swift — Syllabus

> 24 weeks · ~864 hours full-time (~432 hours self-paced)
> Sub-brand **Swift** (`#F05138`) · Crunch Labs tier · GPL-3.0

Twenty-four weeks. Four phases. Six weeks per phase. One capstone. The detail below is the contract: every week has a title, a topic list, a lecture spine, a hands-on mini-project, and a stated skill the cohort should be able to demonstrate before the next week begins.

Cross-platform Swift comes first because a Mac is not required for it. SwiftUI and the iOS surface come next. Production engineering — persistence, performance, security, IAP, push — comes after SwiftUI is internalised. Multi-platform, App Intents, and App Review come last, when the cohort has the maturity to handle Apple's submission pipeline.

---

## Phase map

| Phase | Weeks | Title | Apple Developer membership? | Mac required? |
| --- | --- | --- | --- | --- |
| **I — Foundations** | 1–6 | Swift the language + Vapor server-side | No | No (Linux fine) |
| **II — SwiftUI & State Management** | 7–12 | SwiftUI, SwiftData, navigation, app architecture | No | Yes (Xcode + simulator) |
| **III — Production iOS** | 13–18 | Networking, perf, security, accessibility, IAP, push | Required from week 15 | Yes |
| **IV — Capstone & Polish** | 19–24 | Multi-platform, Widgets, App Intents, App Review | Required | Yes |

---

## Phase I — Foundations (Weeks 1–6)

The goal of Phase I is fluency in Swift the language and in server-side Swift, before any Apple-platform UI work begins. Everything in this phase runs on Linux, macOS, or Windows + WSL2, using the open-source Swift toolchain from `swift.org` and Vapor 4.

### Week 1 — Swift the language, from a typed-OOP perspective

- **Topics.** Swift toolchain install (Linux + Mac), Swift Package Manager (`swift package init`), the REPL, value vs reference types, `let` vs `var`, optionals, type inference, `if let` / `guard let`, basic control flow, `String`, `Array`, `Dictionary`, `Set`, ranges, tuples.
- **Lecture.** "Swift for the typed-OOP engineer" — the parts that map cleanly from Java/Kotlin/C#/TypeScript, and the parts that do not (optionals, value types, no `null`, exhaustive switching).
- **Mini-project.** Write a `swift run wordfreq <file.txt>` CLI that counts word frequencies in a text file, prints the top 20 in a Markdown table, and is fully unit-tested with Swift Testing. Cross-compile and run on Linux and macOS.
- **Skill earned.** Can read and write idiomatic Swift; can structure a SwiftPM executable; can write a Swift Testing target.

### Week 2 — Protocols, generics, error handling

- **Topics.** Protocols, protocol-oriented programming, `associatedtype`, generic functions and types, `some` (opaque) vs `any` (existential) types, type erasure, `Error`, `Result<Success, Failure>`, `throws` / `try` / `try?` / `try!`, custom error enums, `Sequence` and `IteratorProtocol`.
- **Lecture.** "Protocols and generics — why Swift is not Java with cleaner syntax." Includes the existential-vs-opaque decision matrix from the Swift Evolution proposals.
- **Mini-project.** Build a generic `Cache<Key: Hashable, Value>` with TTL eviction, an in-memory backing store, and a disk-backed alternative behind a `CacheStore` protocol. Ship with property tests.
- **Skill earned.** Can design a generic API with protocol-backed dependencies; can pick `some` over `any` deliberately.

### Week 3 — Swift Concurrency I — async / await, structured concurrency

- **Topics.** `async` functions, `await`, `Task`, `TaskGroup`, `async let`, cancellation, priority, `@TaskLocal`, `withTaskCancellationHandler`, sequencing vs concurrency, structured vs unstructured tasks.
- **Lecture.** "The structured concurrency model" — task trees, cancellation propagation, the difference between `Task { }` and `Task.detached`, and why `DispatchQueue` is the past.
- **Mini-project.** Build a parallel link-checker CLI: takes a sitemap.xml, fans out to N concurrent HTTP HEAD requests (default 16), collects results into a `TaskGroup`, supports `--timeout` and graceful Ctrl-C cancellation, prints a final report.
- **Skill earned.** Can implement a structured-concurrency workload with cancellation and back-pressure.

### Week 4 — Swift Concurrency II — Actors, Sendable, strict concurrency

- **Topics.** Actors, actor isolation, `@MainActor`, `nonisolated`, `Sendable`, `@Sendable` closures, reentrancy, actor hopping cost, the Swift 6 strict-concurrency mode, `@unchecked Sendable` and when to reach for it.
- **Lecture.** "Strict concurrency in Swift 6 — what the compiler now enforces, why, and how to migrate." Includes a worked example of removing a data race the compiler now catches.
- **Mini-project.** Convert a callback-based key-value store (provided in starter code) into an actor with strict concurrency enabled. Demonstrate at least three compile-time errors caught by the migration.
- **Skill earned.** Can compile a non-trivial Swift module under strict concurrency without `@unchecked Sendable` shortcuts.

### Week 5 — Vapor — server-side Swift fundamentals

- **Topics.** Vapor 4 project layout, routing, middleware, `Content` protocol, JSON encoding/decoding, Fluent ORM (Postgres), migrations, environment configuration, structured logging with `swift-log`.
- **Lecture.** "Why Vapor — the shape of a production Swift HTTP service." Compares Vapor to Hummingbird, FastAPI, Express, and Rails.
- **Mini-project.** Build a `notes-api` Vapor service with `POST /notes`, `GET /notes`, `GET /notes/:id`, `PATCH /notes/:id`, `DELETE /notes/:id`. Persist to Postgres via Fluent. Authenticate with a bearer-token middleware. Ship a Dockerfile and a `docker compose up` integration test.
- **Skill earned.** Can stand up a Vapor service from blank slate to Dockerized REST endpoint with a real database.

### Week 6 — Shared types, swift-nio basics, Phase I integration

- **Topics.** Sharing a `SwiftPM` package between client and server (the shared `Models` module pattern), `swift-nio` event loops at a high level, Hummingbird as an alternative, OpenTelemetry-Swift basics, `swift-collections` (`OrderedDictionary`, `Deque`, `Heap`).
- **Lecture.** "Shared codable types — the move that pays for the rest of the track." A single `struct Note: Codable, Sendable` lives in a shared package and is imported by both Vapor and (later) the SwiftUI client.
- **Phase I integration project.** Take the `notes-api` from week 5, extract the request/response models into a `NotesCore` SwiftPM package, publish it as a local dependency, and write a Swift CLI client (`notes-cli`) that consumes the API using `URLSession` and the shared types. Both server and CLI run on Linux.
- **Skill earned.** Can architect a SwiftPM workspace that shares types across client and server.

**Phase I gate.** Demo a Vapor service, a CLI client, and a shared package — all running on Linux — with Swift Testing coverage above 70% on the shared package.

---

## Phase II — SwiftUI & State Management (Weeks 7–12)

A Mac with Xcode 16+ is required from week 7 onward. The simulator covers everything in this phase; no physical device is needed yet.

### Week 7 — Xcode, the SwiftUI mental model, first app

- **Topics.** Xcode tour, schemes, build configurations, asset catalogs, `App` and `Scene`, the `View` protocol, `body` as a function of state, the `Layout` protocol, basic primitives (`Text`, `Image`, `Button`, `Stack`s), modifiers, the modifier order rule.
- **Lecture.** "SwiftUI is a function from state to view, with diffing." How `body` is invoked, when re-renders happen, what `EquatableView` and `@ViewBuilder` actually do.
- **Mini-project.** Build "Hello, Notes" — a single-screen SwiftUI app that lists hard-coded notes, supports light/dark mode, Dynamic Type, and renders correctly on iPhone SE and iPad Pro 13-inch in the simulator.
- **Skill earned.** Can structure a SwiftUI view hierarchy and reason about modifier order.

### Week 8 — State: @State, @Observable, @Environment, @Bindable

- **Topics.** Property wrappers (`@State`, `@Binding`, `@Environment`, `@EnvironmentObject` legacy), the `Observation` framework (`@Observable`, `@Bindable`), `@StateObject` vs `@ObservedObject` (legacy), state ownership rules, view identity, `id()` modifier, `onChange(of:)`, `task { }`.
- **Lecture.** "State ownership in SwiftUI — who owns what, and the bug class of getting it wrong." Includes the SwiftUI re-render storm walkthrough.
- **Mini-project.** Add full CRUD to "Hello, Notes" using an `@Observable` `NotesStore`. Inject via `@Environment`. Edit a note in a sheet and confirm the list updates exactly once.
- **Skill earned.** Can pick the correct state primitive for a given ownership scenario and defend the choice in code review.

### Week 9 — Navigation, deep links, scenes

- **Topics.** `NavigationStack`, `NavigationSplitView`, value-typed navigation (`NavigationLink(value:)`), `navigationDestination`, programmatic navigation, deep links (`onOpenURL`), universal links (`Associated Domains`), state restoration, `SceneStorage`, `AppStorage`, tab-based navigation with `TabView`.
- **Lecture.** "Navigation in SwiftUI — the post-iOS-16 model." Why we left `NavigationView` behind, and how value-typed navigation enables deep links by construction.
- **Mini-project.** Add a sidebar-detail layout to "Hello, Notes" for iPad and Mac (`NavigationSplitView`) and a stack layout for iPhone (`NavigationStack`). Support a `notes://open/:id` deep link that opens any note from cold launch.
- **Skill earned.** Can model navigation as state, restore from a cold launch, and handle deep links.

### Week 10 — SwiftData — the modern persistence story

- **Topics.** SwiftData macros (`@Model`, `@Attribute`, `@Relationship`), `ModelContainer`, `ModelContext`, queries with `@Query`, predicates, sort descriptors, lightweight migrations, schema versioning, performance footguns, Core Data interop for legacy.
- **Lecture.** "SwiftData and the Core Data lineage — what it solves, what it still hides, and where to fall back to Core Data." Includes the SwiftData / Core Data co-existence pattern.
- **Mini-project.** Migrate "Hello, Notes" from the in-memory `NotesStore` to SwiftData. Add a `Tag` model with a many-to-many relationship to `Note`. Query notes by tag with a `#Predicate`. Survive an app relaunch.
- **Skill earned.** Can model a SwiftData schema with relationships and query it efficiently.

### Week 11 — App architecture — MVVM, TCA, and the case against VIPER

- **Topics.** Plain SwiftUI + `@Observable` (the "use-the-language" architecture), MVVM as a discipline, **The Composable Architecture (TCA)** by Point-Free, unidirectional data flow, reducers, effects, dependencies, the VIPER critique, when "no architecture" is correct.
- **Lecture.** "Choosing an architecture — three questions that decide it for you." Includes a side-by-side feature implemented in plain SwiftUI, MVVM, and TCA, with code-review comments on each.
- **Mini-project.** Implement the "search and filter notes" feature in two ways: once as plain `@Observable` MVVM, once as a TCA reducer. Write an architectural decision record (ADR) explaining which you would ship and why.
- **Skill earned.** Can implement and critique three architectures; can write an ADR.

### Week 12 — Combine, async/await, and AsyncSequence

- **Topics.** Combine fundamentals (`Publisher`, `Subscriber`, `AnyCancellable`, operators), Combine in SwiftUI (`onReceive`), `AsyncSequence` and `AsyncStream`, bridging Combine to `async/await`, when each is the right tool, debouncing user input with both.
- **Lecture.** "Combine vs async/await — the actual decision matrix, after three years of strict concurrency." Includes the back-pressure comparison.
- **Phase II integration project.** "Notes v1" — a polished SwiftUI iPhone + iPad + Mac app with full CRUD, search-as-you-type (debounced via `AsyncStream`), tag filtering, deep links, dark mode, Dynamic Type, and SwiftData persistence. Survives cold launch state restoration. UI tested with XCUITest.
- **Skill earned.** Can ship a non-trivial SwiftUI app with persistence, navigation, and reactive search.

**Phase II gate.** Demo "Notes v1" on three Apple simulators (iPhone, iPad, Mac), with a recorded screen capture and a code review against the rubric.

---

## Phase III — Production iOS (Weeks 13–18)

Production-engineering depth. Network failure, persistence corruption, hangs, accessibility, security, monetisation, and push delivery. Apple Developer Program membership becomes required at week 15.

### Week 13 — URLSession and the networking stack

- **Topics.** `URLSession` configuration, `URLProtocol`, `URLSessionConfiguration` ephemeral / default / background, async URLSession APIs, typed errors, `Codable` decoding strategies, retries with exponential backoff and jitter, request signing, request/response logging middleware.
- **Lecture.** "A grown-up networking layer in async Swift." From `URLSession.shared.data(for:)` to a typed, retryable, cancellable, instrumented client.
- **Mini-project.** Wire "Notes v1" to the Vapor `notes-api` from Phase I. Build a `NotesClient` actor with structured errors, retries, and offline-detection. Handle the case where the server is unreachable by falling back to SwiftData and replaying writes when it returns.
- **Skill earned.** Can architect a networking layer with offline-first write-replay.

### Week 14 — Persistence II — Files, Keychain, SwiftData + CloudKit

- **Topics.** The iOS file system (`FileManager`, sandbox, App Group containers, Files app), `Keychain` (kSecClass, access groups, sync), atomic writes, file coordination, SwiftData + CloudKit sync, conflict resolution policy, schema-versioned migrations.
- **Lecture.** "Where to put each byte — file system, Keychain, SwiftData, CloudKit." Includes the threat-model decision tree.
- **Mini-project.** Add CloudKit sync to "Notes v1". Store the user's auth token in the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Reproduce a deliberate two-device edit conflict in the simulator and write the conflict-resolution code.
- **Skill earned.** Can persist sensitive credentials in Keychain and resolve a multi-device sync conflict deterministically.

### Week 15 — On-device deployment, performance with Instruments

- **Topics.** Code signing, provisioning profiles, device deployment, **Instruments** (Time Profiler, Hangs, Hitches, Allocations, Memory Graph, Leaks, App Launch, SwiftUI), main-thread hangs, hitches and the 16.67 ms budget, `os_signpost`, the `MetricKit` framework.
- **Lecture.** "Diagnose a hang, a hitch, and a memory leak — with the right Instrument every time." Includes a recorded Instruments capture annotated frame by frame.
- **Apple Developer Program membership required from this week onward.**
- **Mini-project.** Profile "Notes v1" with Time Profiler on a real device. Identify and fix at least one main-thread hang and one hitch in the list scroll. Ship a `MetricKit` collector that prints daily payloads to the console.
- **Skill earned.** Can run an Instruments capture, read a flame graph, and ship a measured performance fix.

### Week 16 — Accessibility and inclusive engineering

- **Topics.** VoiceOver, the accessibility tree, `accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, `accessibilityIdentifier`, Dynamic Type and the `@ScaledMetric` property wrapper, color contrast, reduce motion, audio descriptions, haptics (`UIImpactFeedbackGenerator`, `CHHapticEngine`), the iOS Accessibility Inspector.
- **Lecture.** "Accessibility is engineering, not charity." Includes a VoiceOver walkthrough of the cohort's own app.
- **Mini-project.** Run "Notes v1" with VoiceOver enabled. Fix every failure surfaced by the Accessibility Inspector. Add haptic feedback on note creation and a Dynamic-Type-safe list cell that renders correctly at the largest setting.
- **Skill earned.** Can audit a SwiftUI app for accessibility and ship measurable improvements.

### Week 17 — Security, App Transport Security, CryptoKit, Secure Enclave

- **Topics.** ATS configuration, certificate pinning (URLSession delegate), Keychain access control, `LocalAuthentication` (Touch ID / Face ID), **CryptoKit** (`SymmetricKey`, `AES.GCM`, `Curve25519`, `SHA256`), the **Secure Enclave** (`SecureEnclave.P256`), app-bound storage, sensitive log scrubbing.
- **Lecture.** "Apple's cryptography and key management — what's on-device, what's hardware-backed, what's just convenient." Pin a certificate, sign a request, store a private key in the Secure Enclave.
- **Mini-project.** Add certificate pinning to the `NotesClient`. Generate a Secure Enclave key, sign each outbound request with it, and verify the signature in the Vapor backend with the matching public key.
- **Skill earned.** Can pin a TLS cert, generate a hardware-backed key, and sign requests end-to-end.

### Week 18 — Push notifications, StoreKit 2, MetricKit telemetry

- **Topics.** **APNs** auth keys vs certificates, device token registration, notification payloads, mutable content with a **Notification Service Extension (NSE)**, communication notifications, **StoreKit 2** (`Product`, `Transaction`, `Product.PurchaseOption`), auto-renewing subscriptions, server-side `Transaction.jsonRepresentation` validation, Family Sharing, refund handling.
- **Lecture.** "The push and purchase pipelines — APNs and StoreKit 2 end to end." Includes the signed-receipt verification flow with `Curve25519.Signing`.
- **Phase III integration project.** "Notes Pro v1" — adds APNs (a note shared with you triggers a push), a Notification Service Extension that decrypts the payload, and a StoreKit 2 subscription (`notes_pro_monthly`) gated behind a `Paywall` view. Server validates the receipt against the Vapor backend.
- **Skill earned.** Can ship a real push pipeline and a real subscription with server-side validation.

**Phase III gate.** Demo "Notes Pro v1" on a physical device, prove the push pipeline end-to-end, complete a sandbox subscription purchase, and submit an Instruments-tuned build to TestFlight internal testing.

---

## Phase IV — Capstone & Polish (Weeks 19–24)

Multi-platform, the Apple ecosystem features (App Intents, Widgets, Live Activities), then the capstone build, TestFlight, App Review, and a chaos drill.

### Week 19 — Multi-platform — iOS, iPadOS, macOS (Catalyst + native), watchOS, visionOS

- **Topics.** SwiftUI multi-platform targets, `#if os(...)` discipline, conditional modifiers, Mac Catalyst vs SwiftUI-on-macOS-native, watchOS app structure (`WKApplication`, complications), visionOS basics (RealityKit primitives, `ImmersiveSpace`, `WindowGroup` with `.windowStyle(.volumetric)`).
- **Lecture.** "One codebase, five platforms — what scales, what doesn't, and where you draw the line." Includes the multi-platform target topology.
- **Mini-project.** Add a macOS-native target to "Notes Pro v1" using SwiftUI. Add a watchOS companion app that shows the three most recent notes. Add a visionOS window. Demonstrate all four running side-by-side in their respective simulators.
- **Skill earned.** Can ship one SwiftUI codebase to four Apple platforms.

### Week 20 — Widgets, App Intents, Shortcuts, Spotlight

- **Topics.** **WidgetKit** (`Widget`, `TimelineProvider`, snapshot vs timeline, supported families), Lock Screen widgets, **App Intents** (the framework, not the legacy `IntentDefinition`), Siri suggestions, Shortcuts gallery, **Spotlight** indexing (`CSSearchableIndex`), App Shortcuts.
- **Lecture.** "App Intents — the new contract between your app and the rest of iOS." Walk through registering an intent, exposing it to Shortcuts, and surfacing it in Spotlight.
- **Mini-project.** Add a Home Screen widget that shows the most recent note. Add a Lock Screen widget showing today's note count. Register an `AddNote` App Intent so the user can say "Add a note saying ..." to Siri.
- **Skill earned.** Can ship a Widget Timeline and an App Intent that survives the Shortcuts gallery.

### Week 21 — Live Activities, ActivityKit, background processing

- **Topics.** **ActivityKit** (`ActivityAttributes`, `ContentState`, starting and updating activities), Dynamic Island layouts (compact, minimal, expanded), Push-to-start Live Activities, **BackgroundTasks** framework (`BGAppRefreshTask`, `BGProcessingTask`), background modes, low-power mode and how it changes everything.
- **Lecture.** "Live Activities and background work — the real-time iOS surface." Includes the APNs push-to-start payload and the Dynamic Island layout decision tree.
- **Mini-project.** Add a "shared-note edit in progress" Live Activity that appears when another device starts editing your note. Render compact, minimal, and expanded Dynamic Island layouts. Update the activity via an APNs push from the Vapor backend.
- **Skill earned.** Can ship a Live Activity driven by a backend push.

### Week 22 — Testing at scale, CI on GitHub Actions, fastlane

- **Topics.** XCTest vs **Swift Testing** (the new framework with `@Test`, `#expect`, parameterized tests), UI testing with XCUITest, **snapshot testing** (e.g. `swift-snapshot-testing`), `xcodebuild` on CI, `xcbeautify`, GitHub Actions for iOS (`macos-14` runners), **fastlane** (`gym`, `pilot`, `match`), the **App Store Connect API** for programmatic uploads.
- **Lecture.** "Your iOS CI pipeline — the one a senior engineer would actually trust." End-to-end from `git push` to a TestFlight build appearing in the dashboard.
- **Mini-project.** Stand up a GitHub Actions workflow that runs Swift Testing + XCUITest + snapshot tests on every PR, builds an archive, and uploads to TestFlight on every push to `main`. Use App Store Connect API keys checked into the workflow secrets.
- **Skill earned.** Can ship a complete iOS CI pipeline that goes from commit to TestFlight.

### Week 23 — Capstone build sprint

- **Topics.** Capstone integration, code review, architectural decision records, the `production-runbook.md`, the `interview-prep` system-design pack.
- **Lecture.** Capstone progress review and final architecture sign-off.
- **Mini-project.** **Capstone build sprint** — see full spec below. Cohort works the spec end-to-end; instructors run a daily 30-minute review.
- **Skill earned.** Can integrate everything from Phases I–III into a single cohesive multi-platform system.

### Week 24 — TestFlight, App Review, chaos drill, demo day

- **Topics.** App Store Connect metadata, screenshots (1290×2796 and friends), App Privacy details, App Review guidelines (the actually-enforced ones), TestFlight external beta, beta crash reports, expedited review, the "1.0.1 the day after launch" pattern, **chaos drills** (push key rotation, subscription edge cases, offline edit conflict), the **postmortem**.
- **Lecture.** "Submitting an app to Apple — what App Review really checks, what it never checks, and how to land on the first try."
- **Capstone final week.** Ship the capstone to TestFlight in five regions (US, UK, IN, BR, JP), run the chaos drill, write the postmortem, record the five-minute walkthrough, present at demo day.
- **Skill earned.** Has shipped a real app through Apple's submission pipeline and survived a documented chaos drill.

**Phase IV gate.** The capstone is accepted into TestFlight, the chaos-drill postmortem is signed off, the portfolio is published, and the cohort completes the senior iOS mock interview.

---

## Assessment matrix

| Component | Weight | Cadence | Scoring |
| --- | --- | --- | --- |
| **Weekly mini-projects** (×22) | 30% | Weekly | Rubric: function, structure, tests, perf, accessibility (each 0–4) |
| **Quizzes** (×24) | 10% | Weekly, auto-graded | 10 questions, must average ≥ 7/10 |
| **Phase integration projects** (×3, end of Phases I–III) | 15% | Weeks 6, 12, 18 | Code review + demo |
| **Capstone** | 30% | Weeks 19–24 | Spec compliance + chaos drill + postmortem + video |
| **Career engineering pack** | 10% | Week 24 | Interview prep submission + portfolio review |
| **Code review participation** | 5% | Continuous | ≥ 2 peer reviews per week |

Pass mark: **75%** overall, **no phase gate below 60%**.

---

## Capstone

### Specification — "Offline-First Cross-Device Productivity Suite"

A SwiftUI productivity suite that runs on iPhone, iPad, and Mac with a watchOS companion and a visionOS window, backed by a Vapor service running on Linux. The system must work fully offline, sync across devices over CloudKit (with the Vapor backend as a fallback path), monetise via a StoreKit 2 subscription validated server-side, expose App Intents to Shortcuts and Siri, render Widgets on the Home Screen and Lock Screen, drive a Live Activity from a real-time event, and survive a documented chaos drill.

The product domain is intentionally open — you may build a note suite, a focus-timer suite, a journaling suite, a habit tracker, a workout logger, a recipe planner, or any productivity surface you can defend in scope review. The technical bar is fixed.

### Deliverables

1. **Source code** — public GitHub repository, GPL-3.0, with a clean commit history (squash-merged feature branches).
2. **Architecture diagram** — Mermaid in the repo `README.md`. Show clients, sync paths, CloudKit, Vapor, Postgres, APNs, and the StoreKit validation flow.
3. **Live TestFlight build** — shipped to TestFlight, external beta enabled in **at least five regions** (US, UK, IN, BR, JP). Build link in the README.
4. **Vapor backend** — deployed to a public URL (Fly.io / Railway / a Linux VPS / your own GCP or AWS box). Postgres, structured logging, OpenTelemetry export. Health endpoint and runbook in the repo.
5. **Five-minute walkthrough video** — screen recording with voiceover. Cover the app on three platforms, the Widget, the App Intent, the Live Activity, the subscription flow, and the offline-first sync.
6. **Chaos-drill postmortem** — `postmortem.md` in the repo. Pick **one** of the three drills below, document the failure, the detection, the recovery, the user impact, and the action items.
7. **Production runbook** — `production-runbook.md`. What to check at 3 AM when the push pipeline silently breaks. What to roll back. Who to page. (You are paging yourself; the discipline is the point.)
8. **Portfolio entry** — three polished apps from the track (Notes v1, Notes Pro v1, the capstone), each with its own one-page case study.

### Chaos-drill menu (pick one)

1. **Offline-edit conflict resolution.** Two simulators editing the same note while offline; reconnect both within 60 s of each other. Document the conflict resolution policy you shipped, why you picked it, and how you measured user impact in beta.
2. **Subscription edge cases.** Trigger a real-money refund, a downgrade from a yearly to a monthly plan, and a billing-retry recovery. Verify the server reflects each transition within five minutes. Document each branch.
3. **APNs auth-key rotation.** Rotate the APNs auth key on App Store Connect mid-beta. Document the rollout sequence (new key first, deploy, retire old key), the silent-failure window, and how you proved the pipeline recovered.

### Scoring rubric (capstone, 100 points)

| Criterion | Max |
| --- | --- |
| Multi-platform parity (iPhone + iPad + Mac + watchOS + visionOS) | 15 |
| Offline-first behaviour, sync, conflict resolution | 15 |
| StoreKit 2 subscription with server-side validation | 10 |
| Widgets + App Intents + Live Activity working end-to-end | 15 |
| Vapor backend deployed and healthy | 10 |
| Accessibility audit clean (Inspector + VoiceOver review) | 10 |
| Instruments-tuned (no hitches > 0 per 60 s scroll, no hangs in 5-minute use) | 10 |
| TestFlight build in 5+ regions | 5 |
| Chaos-drill postmortem and runbook | 10 |

Minimum to pass: **70 / 100**.

---

## Career engineering pack

Delivered in week 24, archived to the `interview-prep/` and `portfolio/` directories of the track.

### Interview preparation

- **Senior iOS technical interview drills.** 30 questions across Swift language (`Sendable`, opaque vs existential, actor isolation), SwiftUI (state ownership, navigation modelling, performance debugging), Concurrency (cancellation, back-pressure, structured tasks), Persistence (SwiftData vs Core Data, CloudKit conflict resolution), and Networking (URLSession, retries, certificate pinning). Each with a sample answer and a follow-up.
- **System design with mobile constraints.** Six prompts that include "design Twitter for iOS", "design Spotify offline mode", "design a multi-device journaling app", "design a Live Activity for a food-delivery order", "design photo sync for a family of four", and "design a push pipeline that survives an APNs outage". Each with a reference solution that names the actual Apple frameworks involved.
- **Code review of SwiftUI architecture decisions.** Three real-world PRs (anonymised) with comments — the cohort writes their own review, then compares to the reference review.
- **Behavioural drills.** Five iOS-specific prompts ("walk me through a launch you owned", "what's the worst hitch you've shipped to production", "how did you handle an App Review rejection") with framework answers.

### Portfolio

Three polished apps:

1. **Notes v1** (Phase II) — clean SwiftUI multi-platform CRUD with SwiftData, search, deep links.
2. **Notes Pro v1** (Phase III) — adds APNs, NSE, StoreKit 2 subscription, Instruments tuning.
3. **The capstone** — the multi-platform productivity suite, TestFlight in five regions, runbook, chaos drill postmortem.

Each app gets a `portfolio/<app>/case-study.md` with: problem framing, key architectural decisions, the hardest bug, the production metric, and a screenshot strip.

### Production runbook

A `production-runbook.md` template that covers:

- The on-call surface (APNs, CloudKit, Vapor, StoreKit server notifications, App Store Connect API)
- The five most likely outages and how to detect each
- The rollback procedure for a TestFlight build, an App Store build, and a Vapor deploy
- The communication template for a beta-cohort incident
- The drift checklist before every Apple OS major release

---

## Licensing

This syllabus and all curriculum materials in `C20-CRUNCH-SWIFT/` are licensed under **GPL-3.0**. See [`LICENSE`](./LICENSE).

Course identity, accent colour, and brand position are governed by the [`CRUNCH-LABS-CHARTER.md`](../CRUNCH-LABS-CHARTER.md). The track's design rationale lives in [`CHARTER.md`](./CHARTER.md).
