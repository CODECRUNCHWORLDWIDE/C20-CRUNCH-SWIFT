# Week 19 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **"Bringing multiple windows to your SwiftUI app" + the multiplatform app documentation.** How one SwiftUI app spans platforms and scenes:
  <https://developer.apple.com/documentation/swiftui/scenes>
- **"Building a document-based app with SwiftUI" / the SwiftUI app structure.** The `App`, `Scene`, `WindowGroup` model that's shared across all five platforms:
  <https://developer.apple.com/documentation/swiftui/app-organization>
- **"Choosing a Mac deployment strategy" (Catalyst vs native SwiftUI vs macOS target).** The decision central to lecture 1:
  <https://developer.apple.com/documentation/uikit/mac-catalyst>
- **"Setting up a watchOS project" + the watchOS app structure.** The companion-app model and the watch's SwiftUI surface:
  <https://developer.apple.com/documentation/watchkit>
- **"Hello World" (visionOS) and the visionOS app overview.** Windows, volumes, and immersive spaces — read the *windows* part closely:
  <https://developer.apple.com/documentation/visionos>

## The APIs you'll use (reference, skim don't memorize)

- **`NavigationSplitView` and `.navigationSplitViewStyle`:** <https://developer.apple.com/documentation/swiftui/navigationsplitview>
- **`ToolbarItem` and `ToolbarItemPlacement`:** <https://developer.apple.com/documentation/swiftui/toolbaritemplacement>
- **`WindowGroup` and `WindowStyle` (`.plain`, `.volumetric`):** <https://developer.apple.com/documentation/swiftui/windowgroup>
- **`ImmersiveSpace` (visionOS):** <https://developer.apple.com/documentation/swiftui/immersivespace>
- **`WidgetKit` (for the watch complication):** <https://developer.apple.com/documentation/widgetkit>
- **`WidgetFamily` accessory families (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`):** <https://developer.apple.com/documentation/widgetkit/widgetfamily>
- **`.keyboardShortcut` (Mac):** <https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:)>
- **Compiler conditionals (`#if os(...)`, `#if targetEnvironment(macCatalyst)`):** <https://developer.apple.com/documentation/swift/conditional-compilation-blocks>

## WWDC sessions (free, watch in this order)

- **"Use SwiftUI with UIKit" / "The SwiftUI cookbook for navigation" (WWDC22)** — the adaptive `NavigationSplitView`/`NavigationStack` model that powers per-platform navigation:
  <https://developer.apple.com/videos/play/wwdc2022/10054/>
- **"Bring your app to Mac with Mac Catalyst" + "Take SwiftUI to the next dimension"** — the Mac strategies and the visionOS introduction:
  <https://developer.apple.com/videos/play/wwdc2021/10052/>
- **"Build a productivity app for Apple Vision Pro" / "Principles of spatial design"** — windows-first visionOS, and *when* immersion is appropriate (mostly: not for a notes app):
  <https://developer.apple.com/videos/play/wwdc2023/10115/>
- **"Build a watchOS app" / "What's new in watchOS"** — the watch app structure, glanceable design, and complications:
  <https://developer.apple.com/videos/play/wwdc2022/10133/>
- **"Complications and widgets: Reloaded" (WWDC22)** — watch complications as WidgetKit widgets, the accessory families:
  <https://developer.apple.com/videos/play/wwdc2022/10050/>

## The four ways onto the Mac

- **Mac Catalyst overview ("Optimize for Mac" vs "Scale to fit iPad"):** <https://developer.apple.com/documentation/uikit/mac-catalyst/choosing-a-user-interface-idiom-for-your-mac-app>
- **SwiftUI on macOS (native, AppKit-backed):** <https://developer.apple.com/documentation/swiftui/building-a-macos-app>
- **`#if targetEnvironment(macCatalyst)`** — distinguishing Catalyst from native at compile time: in the conditional-compilation reference above.

## watchOS & complications

- **watchOS app architecture (the `App`/`WindowGroup` model, no `WKHostingController` needed for SwiftUI):** <https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types>
- **`AccessoryWidgetBackground` and accessory rendering modes:** <https://developer.apple.com/documentation/widgetkit/accessorywidgetbackground>
- **The Digital Crown (`.digitalCrownRotation`):** <https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:)>

## visionOS (windows first)

- **Windows, volumes, and spaces (the scope decision):** <https://developer.apple.com/documentation/visionos/presenting-windows-and-spaces>
- **`.windowStyle(.volumetric)` for 3D content (where it fits, not this week's notes window):** <https://developer.apple.com/documentation/swiftui/windowstyle>
- **Apple's "Destination Video" and "Hello World" visionOS samples** — read the *window* code, not just the immersive parts.

## Community writing (current, opinionated, correct)

- **Hacking with Swift — multiplatform, watchOS, and visionOS articles.** Paul Hudson keeps these current per OS release:
  <https://www.hackingwithswift.com/>
- **Majid Jabrayilov ("Swift with Majid") — the multi-platform SwiftUI series.** The best free long-form writing on adaptive navigation and the share/adapt line:
  <https://swiftwithmajid.com/>
- **Natascha Fadeeva / "Tanaschita" — watchOS and visionOS SwiftUI notes:** <https://tanaschita.com/>
- **Apple Developer Forums — SwiftUI, watchOS, and visionOS categories** — where the per-platform edge cases get answered:
  <https://developer.apple.com/forums/tags/swiftui>

## Open-source projects to read this week

You learn more from one hour reading a real multi-platform app than from three hours of tutorials. Pick one and trace where the share/adapt line falls:

- **`apple/sample-food-truck`** — Apple's flagship multiplatform SwiftUI sample (iOS, iPadOS, macOS), with a shared package and adaptive navigation; the exemplar for this week's topology:
  <https://github.com/apple/sample-food-truck>
- **`apple/sample-backyard-birds`** — also runs across platforms with a shared SwiftData + StoreKit core; read how the same models drive different shells:
  <https://github.com/apple/sample-backyard-birds>
- **Any well-structured multiplatform app with a `Core` SwiftPM package** — the pattern to copy is "models/network/logic in a package, thin app targets on top."

## Tools you'll use this week

- **Xcode 16+ with all simulators installed** — iOS, macOS (runs natively), watchOS, and the **visionOS simulator** (a large download — install before Friday). You'll run several at once, which is why Apple Silicon and 16+ GB RAM matter this week.
- **The scheme/destination picker** — switching one shared target across destinations, and running separate watchOS/visionOS targets.
- **`xcodebuild -showdestinations`** — list every destination a target can build for; useful for confirming your multi-platform target's reach.
- **The "Optimize Interface for Mac" / "Scale Interface to Match iPad" toggle** (target ▸ General ▸ Supported Destinations / Mac Catalyst) — to *feel* the difference between the two Catalyst idioms.

## Free reading (chapter-level)

- **Apple's "Bringing your app to multiple platforms" article group** is effectively a free book; read the topology and Mac-strategy articles end to end.
- **The visionOS "Hello World" sample's documentation** is a free, sample-driven mini-book on windows, volumes, and (later) spaces.

## Paid books (optional, clearly marked)

- **"SwiftUI for Masterminds" — J.D Gauchat** (paid). Broad coverage including the multi-platform and watchOS surfaces; useful as a reference.
- **"visionOS development" early titles** (paid, and aging fast — the platform is young). Useful for the immersive material you'll *not* build this week but may want for the capstone stretch.

---

*If a link 404s, please open an issue so we can replace it.*
