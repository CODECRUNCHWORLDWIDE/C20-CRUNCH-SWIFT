# Week 7 — Resources

Every resource on this page is **free**. Apple's developer documentation and WWDC session videos are free without a paid Developer Program membership (you only need a free Apple ID to stream them). SwiftUI itself is Apple-proprietary, but the docs, the sample code, the SF Symbols app, and the WWDC sessions are all free. The open-source repositories linked (`pointfreeco/swift-composable-architecture`, `pointfreeco/swiftui-navigation`) are MIT/free. No paywalled books are linked.

## Required reading (work it into your week)

- **Apple — "Learning SwiftUI"** (the official entry path):
  <https://developer.apple.com/tutorials/swiftui>
- **Apple — `View` protocol reference** (read the "Overview" and "Creating a view"):
  <https://developer.apple.com/documentation/swiftui/view>
- **Apple — `App` protocol reference**:
  <https://developer.apple.com/documentation/swiftui/app>
- **Apple — `Scene` protocol reference**:
  <https://developer.apple.com/documentation/swiftui/scene>
- **Apple — `WindowGroup` reference**:
  <https://developer.apple.com/documentation/swiftui/windowgroup>
- **Apple — "Configuring views" / view modifiers overview** (the modifier-order mental model):
  <https://developer.apple.com/documentation/swiftui/configuring-views>
- **Apple — Human Interface Guidelines: Dark Mode**:
  <https://developer.apple.com/design/human-interface-guidelines/dark-mode>
- **Apple — Human Interface Guidelines: Typography (Dynamic Type)**:
  <https://developer.apple.com/design/human-interface-guidelines/typography>

## The WWDC sessions that actually teach the model

- **"Demystify SwiftUI"** (WWDC21) — still the single best explanation of **identity, lifetime, and dependencies**. Watch it twice. This is the canonical "how `body` is invoked and diffed" talk:
  <https://developer.apple.com/videos/play/wwdc2021/10022/>
- **"Demystify SwiftUI performance"** (WWDC23) — the follow-up: how to keep `body` cheap, why dependencies matter, where `Equatable`/`.equatable()` and view extraction pay off:
  <https://developer.apple.com/videos/play/wwdc2023/10160/>
- **"Compose custom layouts with SwiftUI"** (WWDC22) — the `Layout` protocol, `sizeThatFits`, `placeSubviews`, and the propose/choose/place model made explicit:
  <https://developer.apple.com/videos/play/wwdc2022/10056/>
- **"The SwiftUI cookbook for navigation"** (WWDC22) — not this week's topic, but the best preview of where the milestone app goes in Week 9; skim it now, study it then:
  <https://developer.apple.com/videos/play/wwdc2022/10054/>
- **"What's new in SwiftUI"** (WWDC24 / WWDC25) — the yearly delta. Watch the most recent one to stay current with the framework as it ships each June:
  <https://developer.apple.com/videos/all-videos/?q=what%27s%20new%20in%20swiftui>

## Xcode and the toolchain

- **Apple — Xcode documentation** (the IDE reference; skim "Projects and targets" and "Build system"):
  <https://developer.apple.com/documentation/xcode>
- **Apple — "Configuring a new target in your project"** (targets vs schemes vs configurations):
  <https://developer.apple.com/documentation/xcode/configuring-a-new-target-in-your-project>
- **Apple — "Customizing the build schemes for a project"**:
  <https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project>
- **Apple — "Adding images to your Xcode project"** (asset catalogs, image sets, 1x/2x/3x):
  <https://developer.apple.com/documentation/xcode/adding-images-to-your-xcode-project>
- **Apple — "Specifying your app's color scheme"** / colour sets in the asset catalog:
  <https://developer.apple.com/documentation/xcode/specifying-your-apps-color-scheme>
- **SF Symbols app** — Apple's free Mac app with the full 6,000+ symbol catalog. Download and keep it open while you build; it is how you find symbol names:
  <https://developer.apple.com/sf-symbols/>

## The layout & primitives reference (bookmark these)

- **`Text`**: <https://developer.apple.com/documentation/swiftui/text>
- **`Image`**: <https://developer.apple.com/documentation/swiftui/image>
- **`Label`**: <https://developer.apple.com/documentation/swiftui/label>
- **`Button`**: <https://developer.apple.com/documentation/swiftui/button>
- **`VStack` / `HStack` / `ZStack`**:
  <https://developer.apple.com/documentation/swiftui/vstack>
- **`LazyVGrid` and `GridItem`** (the adaptive grid used in the exercises and mini-project):
  <https://developer.apple.com/documentation/swiftui/lazyvgrid>
- **`Layout` protocol**:
  <https://developer.apple.com/documentation/swiftui/layout>
- **`ViewThatFits`** (the elegant Dynamic-Type reflow tool):
  <https://developer.apple.com/documentation/swiftui/viewthatfits>
- **`@ScaledMetric`** (scale your own metrics with Dynamic Type):
  <https://developer.apple.com/documentation/swiftui/scaledmetric>
- **`DynamicTypeSize`** (and `isAccessibilitySize`):
  <https://developer.apple.com/documentation/swiftui/dynamictypesize>
- **`EnvironmentValues.colorScheme`**:
  <https://developer.apple.com/documentation/swiftui/environmentvalues/colorscheme>
- **`#Preview` macro and previews**:
  <https://developer.apple.com/documentation/swiftui/preview(_:body:)>

## The result builder under `@ViewBuilder`

- **`ViewBuilder` reference**:
  <https://developer.apple.com/documentation/swiftui/viewbuilder>
- **Swift — "Result builders" (the language feature)** in The Swift Programming Language:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/#Result-Builders>
- **`EquatableView`** (and the `.equatable()` modifier):
  <https://developer.apple.com/documentation/swiftui/equatableview>

## Open-source SwiftUI worth reading

- **`pointfreeco/swift-composable-architecture`** — open any feature's `View` and note how `body` reads as a pure function of a store's state. You will implement TCA in Week 11; reading it now reinforces "view is a function of state":
  <https://github.com/pointfreeco/swift-composable-architecture>
- **`pointfreeco/swiftui-navigation`** — small, focused, well-documented; a good model of idiomatic SwiftUI code organisation (relevant in Week 9):
  <https://github.com/pointfreeco/swiftui-navigation>
- **Apple — "Food Truck: Building a SwiftUI multiplatform app"** sample (a full multi-platform SwiftUI codebase from Apple; skim the view layer):
  <https://developer.apple.com/documentation/swiftui/food_truck_building_a_swiftui_multiplatform_app>

## Blogs & references that hold up in 2026

- **Hacking with Swift — "100 Days of SwiftUI"** (Paul Hudson). Free, comprehensive, beginner-to-intermediate. The early days cover exactly this week's primitives and modifiers:
  <https://www.hackingwithswift.com/100/swiftui>
- **Hacking with Swift — "How layout works in SwiftUI"** (the propose/choose/place explainer in plain English):
  <https://www.hackingwithswift.com/books/ios-swiftui/how-layout-works-in-swiftui>
- **Swift with Majid** (Majid Jabrayilov) — consistently excellent, current SwiftUI deep dives, including layout and the environment:
  <https://swiftwithmajid.com/>
- **fatbobman's blog** — detailed write-ups on SwiftUI internals, view lifetime, and the layout system:
  <https://fatbobman.com/en/>

## How to use this resource list

The lectures cite specific URLs from this page. When a lecture says "see the `Layout` protocol reference," you will find the URL above. You do **not** need to read every link this week. The four things to actually watch/read end-to-end:

1. **"Demystify SwiftUI"** (WWDC21). Non-negotiable. It *is* Lecture 01, from Apple's mouth.
2. **Apple — `View` protocol reference** ("Overview" + "Creating a view"). 15 minutes; grounds the contract.
3. **Hacking with Swift — "How layout works in SwiftUI."** 20 minutes; the clearest propose/choose/place explainer in plain English.
4. **"Compose custom layouts with SwiftUI"** (WWDC22) — only if you attempt the custom-`Layout` stretch goal; otherwise bookmark it for later.

The rest is reference material — bookmark and return to it when a specific question arises.

---

*Bookmarks decay. Apple occasionally restructures `developer.apple.com`; if a link rots, search the page title — these are all canonical and reappear under the same names. WWDC sessions are permanent at the URLs above.*
