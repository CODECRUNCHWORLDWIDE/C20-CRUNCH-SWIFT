# Week 9 — Resources

Every resource on this page is **free**. Apple's developer documentation and the WWDC session videos are free without a paid account. The open-source repositories are MIT- or Apache-licensed and public on GitHub. The blog posts are free to read. No paywalled books are required; the two recommended books are listed at the end as optional depth, not as prerequisites.

A note on currency: SwiftUI's navigation APIs stabilised in iOS 16 (2022) and have been refined through iOS 17 (`NavigationPath` `CodableRepresentation`, `ContentUnavailableView`) and iOS 18 (the new `Tab` builder, `TabView` sidebar adaptivity). Everything here is current as of **Xcode 16 / iOS 18 / iPadOS 18 / macOS 15**, the 2026 baseline for this course. If a Stack Overflow answer mentions `NavigationView` or `isActive:`, it predates this model — read it only to recognize what to replace.

## Required reading (work it into your week)

- **Apple — SwiftUI Navigation (API collection)** — the umbrella page that links `NavigationStack`, `NavigationSplitView`, `navigationDestination`, and `NavigationPath`:
  <https://developer.apple.com/documentation/swiftui/navigation>
- **Apple — `NavigationStack`** — the reference, including the `path:` initializers and the `[Hashable]` vs `NavigationPath` choice:
  <https://developer.apple.com/documentation/swiftui/navigationstack>
- **Apple — `navigationDestination(for:destination:)`** — the destination registry, with the placement rules:
  <https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)>
- **Apple — `NavigationSplitView`** — two- and three-column layouts, column visibility, the compact collapse:
  <https://developer.apple.com/documentation/swiftui/navigationsplitview>
- **Apple — "Migrating to new navigation types"** — the official guide from `NavigationView` to the post-iOS-16 model; read this to know exactly what you are leaving behind:
  <https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types>
- **Apple — `TabView`** and the iOS 18 `Tab`:
  <https://developer.apple.com/documentation/swiftui/tabview>
- **Apple — `SceneStorage`** — per-scene restoration storage:
  <https://developer.apple.com/documentation/swiftui/scenestorage>
- **Apple — `AppStorage`** — the typed `UserDefaults` wrapper:
  <https://developer.apple.com/documentation/swiftui/appstorage>
- **Apple — `View/onOpenURL(perform:)`** — the custom-scheme transport:
  <https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:)>
- **Apple — "Allowing apps and websites to link to your content" (universal links overview)**:
  <https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content>
- **Apple — "Supporting universal links in your app"** — the AASA file, the entitlement, the handler:
  <https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app>
- **Apple — "Defining a custom URL scheme for your app"**:
  <https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app>

## WWDC sessions (free, no account)

- **WWDC22 — "The SwiftUI cookbook for navigation"** — the session that introduced `NavigationStack`, `navigationDestination`, value-typed links, and `NavigationSplitView`. The single most important video for this week. Reproduce its recipe-browser example from memory:
  <https://developer.apple.com/videos/play/wwdc2022/10054/>
- **WWDC22 — "What's new in SwiftUI"** — the navigation section places the new APIs in context:
  <https://developer.apple.com/videos/play/wwdc2022/10052/>
- **WWDC19 — "Window management in your multitasking app" / scenes background** — for the `Scene`/`WindowGroup` mental model that `SceneStorage` is scoped to:
  <https://developer.apple.com/videos/play/wwdc2019/258/>
- **WWDC20 — "Build apps that share data through CloudKit and Core Data" (state restoration section)** — older, but the restoration discussion is still the clearest articulation of the cold-launch problem:
  <https://developer.apple.com/videos/play/wwdc2020/>
- **WWDC24 — "Migrate your TabView and SplitView"-style sessions / "What's new in SwiftUI" (iOS 18)** — the new `Tab` builder and `TabView` sidebar adaptivity introduced for iPad:
  <https://developer.apple.com/videos/play/wwdc2024/10144/>

## Tools you will actually run this week

- **`xcrun simctl openurl booted <url>`** — fire a deep link at the booted simulator from the terminal. This is how you test `notes://open/<id>` without building a second app to send the link. Documented under `xcrun simctl help openurl`.
- **`xcrun simctl terminate booted <bundleID>`** + **`xcrun simctl launch booted <bundleID>`** — the cold-launch reproduction pair from Lecture 1. Terminate kills the process; launch is the cold start that should restore state.
- **AASA Validator (Branch)** — paste a domain and it tells you whether the `apple-app-site-association` file is reachable, correctly typed, and well-formed. Even though you serve yours locally for the challenge, run a real domain through it once to see what iOS checks:
  <https://branch.io/resources/aasa-validator/>
- **`python3 -m http.server`** — used in the challenge to serve the AASA file locally. (Note: it serves HTTP, not HTTPS; the challenge explains the simulator workaround that lets you test universal links without a TLS cert.)
- **Console.app / `log stream`** — to watch `swcd` (the Apple `sharedwebcredentialsd`/SWC daemon) fetch and evaluate your AASA file. `log stream --predicate 'subsystem == "com.apple.swc"'` shows the association attempts when the app installs.

## Open-source repositories worth reading

- **pointfreeco/swift-composable-architecture** — read the `Navigation` documentation and the `NavigationStackStore`. You will not use TCA until Week 11, but seeing how a serious library models navigation as state validates the plain-SwiftUL approach you learn here:
  <https://github.com/pointfreeco/swift-composable-architecture>
- **apple/sample-food-truck** — Apple's multi-platform SwiftUI sample, which uses `NavigationSplitView` and value-typed navigation across iPhone, iPad, and Mac. The closest official analog to this week's mini-project:
  <https://github.com/apple/sample-food-truck>
- **Dimillian/IceCubesApp** — a real, shipping Mastodon client in SwiftUI with a hand-rolled value-typed `Router`/`RouterPath`. Read `Packages/Env/Sources/Env/Router.swift` to see a production codebase model navigation exactly the way this week teaches, then wrap it in a router for Week 11:
  <https://github.com/Dimillian/IceCubesApp>

## Authoritative blog posts and deep dives

- **Apple Developer Forums — universal links troubleshooting threads** — search "apple-app-site-association not working." The accepted answers are a checklist of every AASA footgun (redirects, wrong Content-Type, Team ID typos, CDN caching). Read three of them before the challenge:
  <https://developer.apple.com/forums/tags/universal-links>
- **Donny Wals — "Navigation in SwiftUI" series** — a careful, current walk-through of `NavigationStack`, `navigationDestination`, and programmatic navigation, with the gotchas called out:
  <https://www.donnywals.com/>
- **Swift with Majid — "Mastering NavigationStack in SwiftUI"** — concise, code-first, updated for the current APIs:
  <https://swiftwithmajid.com/>
- **Point-Free — "SwiftUI Navigation" episodes / `swift-navigation` library docs** — the deepest treatment of navigation-as-state in the ecosystem, including the argument for why URL-driven navigation is the same as state-driven navigation:
  <https://www.pointfree.co/>

## Optional depth (books)

- **"Thinking in SwiftUI" — objc.io (Chris Eidhof, Florian Kugler)** — the chapter on the SwiftUI runtime and view identity underpins why navigation-as-state behaves the way it does. Optional; helpful if Week 7's diffing model still feels fuzzy.
- **"SwiftUI Field Guide" — Chris Eidhof (free, interactive, online)** — not a navigation book per se, but the layout and state chapters are the best free reference for the substrate this week sits on:
  <https://www.swiftuifieldguide.com/>

## How to use this list

Do not read all of it. Read in this order:

1. **Watch** the WWDC22 navigation cookbook (45 min) — it is the spine of the whole week.
2. **Read** the `NavigationStack`, `navigationDestination`, and `NavigationSplitView` reference pages while you do Exercise 1 and 2 — keep them open in a browser tab.
3. **Read** Apple's "Supporting universal links" page the morning you start the challenge, and keep the AASA forum threads open while you debug.
4. **Skim** the IceCubesApp `Router` once you have shipped the mini-project, to see your week's lesson in a production codebase.

Everything else is reference you pull from when a specific question arises. Do not let the reading crowd out the building — this is a week where you learn by terminating the simulator and watching the right note come back.
