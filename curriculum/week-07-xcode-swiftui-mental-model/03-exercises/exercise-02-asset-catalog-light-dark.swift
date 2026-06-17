// Exercise 2 — Asset Catalog, Light & Dark
//
// Goal: Prove that a view built on SEMANTIC and ASSET-CATALOG colours adapts
//       between light and dark mode with ZERO branching code. You configure
//       one colour set in the asset catalog, reference it by name, and watch
//       the system re-resolve it when the appearance flips.
//
// Estimated time: 35 minutes.
//
// HOW TO RUN THIS FILE
//
//   This is a complete SwiftUI view. Use it one of two ways:
//
//   (A) New Xcode project: File > New > Project > iOS > App ("ColorAdapt",
//       SwiftUI, Swift, storage None). Replace ContentView.swift's contents
//       with this file's contents (keep one #Preview). Then do the
//       "ASSET CATALOG STEPS" below to add the "CardBackground" colour set.
//
//   (B) Swift Playground app (.swiftpm) in Xcode — same steps, add the colour
//       set in the bundled Assets catalog.
//
//   Build & run (Cmd-R). The code below is correct and renders as written; the
//   "CardBackground" reference falls back gracefully until you add the colour
//   set, at which point the card picks up your custom light/dark colours.
//
// ASSET CATALOG STEPS (do these once, in Assets.xcassets)
//
//   1. Open Assets.xcassets in the project navigator.
//   2. Right-click in the empty area > New Color Set. Name it exactly
//      "CardBackground".
//   3. Select it. In the Attributes inspector (Cmd-Opt-4), set "Appearances"
//      to "Any, Dark".
//   4. Click the "Any Appearance" well and set it to a light off-white, e.g.
//      sRGB R=0.96 G=0.96 B=0.97.
//   5. Click the "Dark" well and set it to a dark charcoal, e.g.
//      sRGB R=0.12 G=0.12 B=0.14.
//   6. (Optional) Also confirm the project's AccentColor set exists; SwiftUI's
//      `.tint` reads it. A fresh project ships one.
//
//   That is the entire configuration. No code branches on colour scheme to
//   pick the card colour — the asset catalog does it for you.
//
// WHAT TO INTERNALISE
//
//   - Color("CardBackground") resolves through the asset catalog, which holds
//     a light value AND a dark value. The system picks the right one.
//   - Color.primary / .secondary and the systemBackground family are SEMANTIC:
//     they describe a role and flip automatically.
//   - @Environment(\.colorScheme) lets you READ the current appearance — use it
//     to display state, NOT to manually choose colours (that's the anti-pattern
//     this exercise exists to retire).

import SwiftUI

// ----------------------------------------------------------------------------
// A small "settings card" that is entirely appearance-adaptive.
// ----------------------------------------------------------------------------

struct AdaptiveCard: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.tint)            // resolves from AccentColor
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)     // semantic: flips automatically
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)   // semantic: flips automatically
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Asset-catalog colour set. Add "CardBackground" per the steps above;
        // until then it falls back to a sensible default and still renders.
        .background(Color("CardBackground"))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// ----------------------------------------------------------------------------
// A badge that READS the current appearance (the only legitimate use of
// @Environment(\.colorScheme): to display, not to branch colour choices).
// ----------------------------------------------------------------------------

struct ColorSchemeBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(
            colorScheme == .dark ? "Dark mode" : "Light mode",
            systemImage: colorScheme == .dark ? "moon.fill" : "sun.max.fill"
        )
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground), in: .capsule)
    }
}

// ----------------------------------------------------------------------------
// The screen.
// ----------------------------------------------------------------------------

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ColorSchemeBadge()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                AdaptiveCard(
                    title: "Notifications",
                    subtitle: "Sounds, badges, and banners",
                    symbol: "bell.badge.fill"
                )
                AdaptiveCard(
                    title: "Appearance",
                    subtitle: "Follows the system setting",
                    symbol: "circle.lefthalf.filled"
                )
                AdaptiveCard(
                    title: "Privacy",
                    subtitle: "Control what the app can access",
                    symbol: "hand.raised.fill"
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))  // semantic group background
    }
}

// ----------------------------------------------------------------------------
// Previews — render BOTH appearances side by side, with no code change.
// ----------------------------------------------------------------------------

#Preview("Light") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

// ----------------------------------------------------------------------------
// YOUR TURN
// ----------------------------------------------------------------------------
//
// 1. Add the "CardBackground" colour set as described in ASSET CATALOG STEPS.
//    Build & run. Toggle Dark Mode in the running app:
//       Simulator > Features > Toggle Appearance  (or Cmd-Shift-A)
//    Watch the cards' background flip — without any `if colorScheme == ...`
//    branch in the card. That is the whole point.
//
// 2. ANTI-PATTERN DRILL. Someone on your team wrote the card background like
//    this, branching on the colour scheme by hand:
//
//        @Environment(\.colorScheme) private var scheme
//        var cardColor: Color {
//            scheme == .dark
//                ? Color(red: 0.12, green: 0.12, blue: 0.14)
//                : Color(red: 0.96, green: 0.96, blue: 0.97)
//        }
//        // ... .background(cardColor)
//
//    Explain in a comment why the asset-catalog approach is better. (Hint:
//    increased-contrast accessibility variants, future appearances, one source
//    of truth, designer-editable without recompiling.)
//
// 3. Add a THIRD appearance variant: in the CardBackground colour set, set
//    "High Contrast" on and give the dark high-contrast well a near-black.
//    Enable Increase Contrast in the simulator
//    (Settings > Accessibility > Display & Text Size > Increase Contrast) and
//    confirm the card picks up the high-contrast value — again, with no code.
//
// ----------------------------------------------------------------------------
// ACCEPTANCE CRITERIA
// ----------------------------------------------------------------------------
//
//   [ ] Build Succeeded with zero warnings.
//   [ ] The "CardBackground" colour set exists with distinct light and dark
//       values, and the running app's cards visibly flip when you toggle
//       appearance.
//   [ ] There is ZERO `if colorScheme == .dark` branch that CHOOSES a colour
//       anywhere in your card. The only use of colorScheme is the badge, which
//       merely DISPLAYS the current mode.
//   [ ] Both #Preview variants ("Light" and "Dark") render correctly in the
//       Canvas.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck >10 min)
// ----------------------------------------------------------------------------
//
//   - If Color("CardBackground") shows as a default fill, the name does not
//     match. It must match the colour-set name EXACTLY, case-sensitive.
//   - To toggle appearance in the running app, the keyboard shortcut in the
//     iOS Simulator is Cmd-Shift-A, or Features > Toggle Appearance.
//   - In the Canvas, `.preferredColorScheme(.dark)` forces a preview's
//     appearance without touching the device setting — that is why the two
//     #Preview blocks differ by exactly one modifier.
//   - `.foregroundStyle(.primary/.secondary/.tertiary)` are the modern
//     semantic text styles; they replace the older `.foregroundColor(...)`.
