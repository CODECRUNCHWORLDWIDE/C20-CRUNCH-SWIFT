# Week 15 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free. The WWDC sessions are free on the Developer site and on YouTube. The tooling (Xcode, Instruments) is free. The one thing this week that is *not* free is the **Apple Developer Program membership ($99/year)**, which is required to deploy to a device and profile a release build — that's the cost of this week, and you were warned in Week 14 to buy it.

## Required reading (work it into your week)

- **"Distributing your app for beta testing and releases" / code-signing overview.** The certificate / App ID / profile model:
  <https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases>
- **"Running your app in Simulator or on a device."** The actual deploy flow:
  <https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device>
- **Instruments — "Improving your app's performance."** The diagnostic mental model — central to lecture 2:
  <https://developer.apple.com/documentation/xcode/improving-your-app-s-performance>
- **"Analyzing responsiveness issues / hangs."** The hang model and the Hangs instrument:
  <https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app>
- **"Analyzing hitches in your app."** The frame budget and the Animation Hitches instrument:
  <https://developer.apple.com/documentation/xcode/understanding-user-interface-responsiveness>

## Code signing (reference)

- **Certificates, Identifiers & Profiles** (the developer portal): <https://developer.apple.com/account/resources/>
- **`codesign` man page** (inspect a signed bundle): run `man codesign`, or <https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html>
- **Capabilities and entitlements:** <https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app>
- **`xcodebuild`** (the build behind ⌘R): run `man xcodebuild`.

## Instruments and performance (reference)

- **Time Profiler:** <https://help.apple.com/instruments/mac/current/#/dev44b2b437>
- **Allocations and Leaks:** <https://help.apple.com/instruments/mac/current/#/dev1996e1f3>
- **`OSSignposter` / `os_signpost`:** <https://developer.apple.com/documentation/os/ossignposter>
- **`OSLog` / `Logger`:** <https://developer.apple.com/documentation/os/logger>
- **The Memory Graph debugger:** <https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use>

## MetricKit (reference)

- **MetricKit framework:** <https://developer.apple.com/documentation/metrickit>
- **`MXMetricManager` / `MXMetricManagerSubscriber`:** <https://developer.apple.com/documentation/metrickit/mxmetricmanager>
- **`MXMetricPayload`** (launch, hang, memory, hitch metrics): <https://developer.apple.com/documentation/metrickit/mxmetricpayload>
- **`MXDiagnosticPayload`** (crash, hang, CPU-exception diagnostics): <https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload>

## WWDC sessions (free, watch in this order)

- **"Explore UI animation hitches and the render loop"** (WWDC23/older) — the frame budget and what a hitch is:
  <https://developer.apple.com/videos/play/tech-talks/10855/>
- **"Understand and eliminate hangs from your app"** (WWDC21) — the hang model and the fix:
  <https://developer.apple.com/videos/play/wwdc2021/10258/>
- **"Detect and diagnose memory issues"** (WWDC) — Allocations, Leaks, the Memory Graph:
  <https://developer.apple.com/videos/play/wwdc2021/10180/>
- **"Diagnose performance issues with the Xcode Organizer"** (WWDC) — MetricKit in the field:
  <https://developer.apple.com/videos/play/wwdc2020/10076/>
- **"What's new in MetricKit"** and **"Identify trends with the Power and Performance API":**
  <https://developer.apple.com/videos/play/wwdc2020/10081/>
- **"Demystify code signing"** — the four pieces, from Apple:
  <https://developer.apple.com/videos/play/wwdc2021/10204/>

## The mental model (why this matters)

The single hardest thing to internalize this week is *measure before you optimize*. These make the case better than we can:

- **Apple — "Reducing your app's launch time"** (a worked measure-then-fix example):
  <https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time>
- **The 16.67 ms / 8.33 ms budget** — burn it into memory. Every frame is a deadline; missing it is a hitch.

## Community writing (current, opinionated, correct)

- **Hacking with Swift — Instruments and performance articles.** Paul Hudson keeps these current:
  <https://www.hackingwithswift.com/>
- **Point-Free — performance and SwiftUI re-render episodes** (paid for full, free previews are instructive):
  <https://www.pointfree.co/>
- **Donny Wals — profiling SwiftUI and concurrency articles:**
  <https://www.donnywals.com/category/swift/>
- **SwiftLee (Antoine van der Lee) — Instruments and signpost tutorials:**
  <https://www.avanderlee.com/>

## Tools you'll use this week

- **Xcode 16+ and Instruments** (bundled). Profile with **Product ▸ Profile** (⌘I).
- **A physical iPhone or iPad** on iOS 17+/18. The honest measurements live only here.
- **`codesign -dvvv` / `codesign -d --entitlements :-`** — inspect what actually signed a build and what entitlements it claims.
- **`xcrun simctl`** — still useful, but remember: **performance numbers come from the device in Release, never the Simulator.**
- **Console.app** — read your `OSLog`/`os_signpost` output and MetricKit logs from the device live.
- **The Xcode Organizer ▸ Metrics** — aggregated MetricKit data from real users (once you've shipped, Phase IV).

## Free books (chapter-level, not whole books)

- **Apple's "Improving your app's performance" documentation group** reads as a free book; the hangs, hitches, and memory articles end to end are the core of this week.

## Paid books (optional, clearly marked)

- **"Advanced Apple Debugging & Reverse Engineering" — Kodeco** (paid). Goes far beyond this week, but the chapters on `codesign`, entitlements, and the signing internals are the clearest deep treatment in print.
- **"Pro iOS Performance" / similar** (paid, varies by year). Useful if performance becomes your specialty; Instruments + measure-fix-measure is the throughline.

---

*If a link 404s, please open an issue so we can replace it.*
