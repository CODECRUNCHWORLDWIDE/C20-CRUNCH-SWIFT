# Week 16 — Resources

Every primary resource on this page is **free**. Apple's developer documentation and the Human Interface Guidelines are free. The WWDC sessions are free on the Developer site and on YouTube. The Accessibility Inspector ships with Xcode. The WCAG reference is a free public standard. No paid membership is needed for any of this week's audit work.

## Required reading (work it into your week)

- **"Accessibility" — SwiftUI documentation.** The modifier index and articles — your reference for `accessibilityLabel`, traits, and tree shaping:
  <https://developer.apple.com/documentation/swiftui/accessibility-fundamentals>
- **Human Interface Guidelines — Accessibility.** The design-side bar: VoiceOver, Dynamic Type, contrast, motion:
  <https://developer.apple.com/design/human-interface-guidelines/accessibility>
- **"Performing accessibility testing for your app."** How to audit — the Accessibility Inspector and on-device VoiceOver:
  <https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app>
- **"Improving accessibility support in your app."** The end-to-end "make a SwiftUI app accessible" guide:
  <https://developer.apple.com/documentation/swiftui/accessibility-modifiers>
- **WCAG 2.2 — the contrast and inclusive-design standard** (the bar the Inspector's audit checks against):
  <https://www.w3.org/WAI/WCAG22/quickref/>

## The accessibility modifiers (reference, skim don't memorize)

- **`accessibilityLabel(_:)`:** <https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv>
- **`accessibilityValue(_:)` / `accessibilityHint(_:)`:** <https://developer.apple.com/documentation/swiftui/view/accessibilityvalue(_:)-6lℓt>
- **`accessibilityAddTraits(_:)` and `AccessibilityTraits`:** <https://developer.apple.com/documentation/swiftui/accessibilitytraits>
- **`accessibilityElement(children:)`:** <https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:)>
- **`accessibilityAction(named:)`:** <https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)>
- **`@AccessibilityFocusState`:** <https://developer.apple.com/documentation/swiftui/accessibilityfocusstate>
- **`@ScaledMetric`:** <https://developer.apple.com/documentation/swiftui/scaledmetric>
- **`DynamicTypeSize`:** <https://developer.apple.com/documentation/swiftui/dynamictypesize>

## Environment values and haptics (reference)

- **`\.accessibilityReduceMotion`:** <https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion>
- **`\.accessibilityDifferentiateWithoutColor`:** <https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilitydifferentiatewithoutcolor>
- **`.sensoryFeedback(_:trigger:)`:** <https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)>
- **`UIImpactFeedbackGenerator`:** <https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator>
- **`CHHapticEngine` / Core Haptics:** <https://developer.apple.com/documentation/corehaptics>
- **`UIAccessibility` (announcements, notifications):** <https://developer.apple.com/documentation/uikit/uiaccessibility>

## WWDC sessions (free, watch in this order)

- **"Writing great accessibility labels"** (WWDC) — exactly how to phrase a label:
  <https://developer.apple.com/videos/play/wwdc2019/254/>
- **"SwiftUI accessibility: Beyond the basics"** (WWDC21) — tree shaping, custom actions, rotors:
  <https://developer.apple.com/videos/play/wwdc2021/10119/>
- **"Build accessible apps with SwiftUI and UIKit"** (WWDC) — the SwiftUI accessibility model:
  <https://developer.apple.com/videos/play/wwdc2024/10073/>
- **"Get started with Dynamic Type"** and **"Make your app visually accessible":**
  <https://developer.apple.com/videos/play/wwdc2024/10074/>
- **"Practice audits to improve accessibility"** (WWDC22) — the audit workflow and `performAccessibilityAudit`:
  <https://developer.apple.com/videos/play/wwdc2022/10153/>
- **"Create custom haptic patterns with Core Haptics":**
  <https://developer.apple.com/videos/play/wwdc2019/520/>

## Why this matters (the case beyond "it's right")

- **OWASP / legal:** The European Accessibility Act (2025) and ADA case law make this a legal requirement in major markets.
- **EN 301 549 / Section 508** — the procurement standards that gate enterprise and government contracts:
  <https://www.section508.gov/>
- **App Review guidelines** — accessibility issues are a rejection reason:
  <https://developer.apple.com/app-store/review/guidelines/>

## Community writing (current, opinionated, correct)

- **Hacking with Swift — accessibility articles.** Paul Hudson, current per OS release:
  <https://www.hackingwithswift.com/quick-start/swiftui>
- **Mobile A11y (Rob Whitaker) — "Developing Accessible iOS Apps."** The most thorough iOS-accessibility writing online:
  <https://mobilea11y.com/>
- **SwiftLee (Antoine van der Lee) — accessibility and Dynamic Type tutorials:**
  <https://www.avanderlee.com/>
- **Apple Developer Forums — Accessibility category** — where the edge cases get answered:
  <https://developer.apple.com/forums/tags/accessibility>

## Tools you'll use this week

- **Accessibility Inspector** — Xcode ▸ Open Developer Tool ▸ Accessibility Inspector. Audit, inspect, simulate VoiceOver.
- **VoiceOver on a device** — Settings ▸ Accessibility ▸ VoiceOver. Set the Accessibility Shortcut (triple-click side button) to toggle it fast. The **screen curtain** is three-finger triple-tap.
- **Dynamic Type** — Settings ▸ Display & Text Size ▸ Larger Text; drag to AX5 to test the largest size. Or the preview canvas's Dynamic Type slider.
- **Color filters / contrast** — Settings ▸ Accessibility ▸ Display & Text Size ▸ Color Filters (simulate color blindness), Increase Contrast, Reduce Motion, Reduce Transparency.
- **`XCUIApplication.performAccessibilityAudit()`** — run the audit in a UI test so accessibility regressions fail CI.

## Free books (chapter-level, not whole books)

- **Apple's "Accessibility" documentation group** reads as a free book; the SwiftUI accessibility articles plus the HIG Accessibility chapter end to end are the core.
- **Rob Whitaker's mobilea11y.com** is effectively a free book on iOS accessibility, chapter by chapter.

## Paid books (optional, clearly marked)

- **"Developing Accessible iOS Apps" — Rob Whitaker** (paid). The definitive book; goes well beyond one week into Switch Control, Voice Control, and audio graphs.

---

*If a link 404s, please open an issue so we can replace it.*
