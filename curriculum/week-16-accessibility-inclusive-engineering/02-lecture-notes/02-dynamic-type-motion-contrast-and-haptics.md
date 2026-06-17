# Lecture 2 — Dynamic Type, motion, contrast, and haptics: comfortable for every perception

Lecture 1 made the app *operable* without sight by building the accessibility tree on purpose. This lecture covers the rest of inclusive engineering — the things that make the app *comfortable and usable across the full range of human perception*: **Dynamic Type** so it's readable at any text size, **reduce-motion and contrast** so it respects users who need calmer or higher-contrast UI, color choices that don't fail color-blind users, and **haptics** as a non-visual feedback channel. These are less famous than VoiceOver but break for *far* more users — a huge fraction of people bump up their text size, and the app that clips at the largest setting is broken for all of them.

The throughline from lecture 1 holds: each of these is *audited with a tool and fixed to a bar*, not asserted. And each has a classic footgun we'll name, show breaking, and fix — measured, not hand-waved.

---

## 1. Dynamic Type — readable at any size

**Dynamic Type** is iOS's user-controlled text-size setting. Users set it in Settings ▸ Display & Text Size ▸ Larger Text, and it ranges from extra-small up through five **accessibility sizes** (AX1–AX5). At AX5, text is *enormous* — and a meaningful number of users live there, because they need to. Your app must remain readable and usable across the whole range, and the failure mode is brutal: text that truncates, overflows, or gets clipped by a hard-coded frame, turning your clean cell into an unreadable mess.

The foundation is **text styles**. Use the semantic styles (`.body`, `.headline`, `.caption`, `.title`, …) and SwiftUI scales them with the user's setting automatically:

```swift
// GOOD — semantic text styles scale with Dynamic Type for free.
Text(note.title).font(.headline)
Text(note.body).font(.body)
Text(note.updatedAt, style: .relative).font(.caption)

// BAD — a fixed point size IGNORES the user's Dynamic Type setting entirely.
Text(note.title).font(.system(size: 17))   // stuck at 17pt no matter what the user set
```

A `.system(size:)` font is frozen — it does not respond to Dynamic Type, so a user at AX5 gets the same tiny 17pt text they couldn't read in the first place. Always reach for a text *style*. If you need a custom font, use `.custom(_:size:relativeTo:)` so it still scales relative to a text style.

The harder part is **layout that survives the large sizes.** The classic breakage:

```swift
// BAD — a hard-coded height clips the text at large Dynamic Type sizes.
HStack {
    Image(systemName: "note.text")
    Text(note.title)
}
.frame(height: 44)            // at AX5 the title needs 80pt of height; it CLIPS

// GOOD — let the cell size to its content; don't pin the height.
HStack {
    Image(systemName: "note.text")
    Text(note.title)
}
.padding(.vertical, 8)        // padding, not a fixed height — the cell grows with the text
```

And for cells where an icon and text sit side by side, at the largest sizes a horizontal layout runs out of width and the text wraps awkwardly or truncates. The pattern is to **reflow to vertical at accessibility sizes**:

```swift
struct AdaptiveRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let note: Note

    var body: some View {
        // At accessibility sizes, stack vertically so the text has full width.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(alignment: .center))

        layout {
            Image(systemName: "note.text")
            Text(note.title).font(.headline)
        }
    }
}
```

`dynamicTypeSize.isAccessibilitySize` tells you the user is in the AX range, and `AnyLayout` lets you swap the layout container without duplicating the subviews. This is the senior move for a cell that must work from extra-small to AX5: reflow, don't clip.

---

## 2. `@ScaledMetric` — scaling the non-text dimensions

Text scales via text styles, but the *other* dimensions — an icon's size, the spacing around it, a custom control's height — don't scale automatically, and if they stay fixed while the text grows, the layout looks wrong (a tiny icon next to huge text). `@ScaledMetric` is the property wrapper that scales a numeric value with Dynamic Type:

```swift
struct TagChip: View {
    let name: String
    // Scales with Dynamic Type, relative to the .body text style. At AX5 the
    // icon and padding grow proportionally with the text, so the chip stays balanced.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
                .font(.system(size: iconSize))   // scales with the text
            Text(name).font(.body)
        }
        .padding(.horizontal, horizontalPadding)  // scales too
        .background(Capsule().fill(.quaternary))
    }
}
```

Without `@ScaledMetric`, the icon stays 14pt and the padding stays 10pt while the text balloons to AX5 — a chip with a microscopic icon and cramped padding around enormous text. With it, the whole chip scales coherently. The `relativeTo:` parameter ties the scaling curve to a text style so the icon grows in step with the text it sits beside. **Any fixed dimension that sits next to scaling text should be a `@ScaledMetric`** — that's the rule.

---

## 3. Reduce Motion and the other comfort settings

Some users find animation disorienting or nauseating, and turn on **Reduce Motion** (Settings ▸ Accessibility ▸ Motion). When they do, your app should *suppress or simplify* its animations — replace a slide or a scale or a parallax with a gentle cross-fade or no animation at all. You read the setting from the environment:

```swift
struct DetailReveal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        VStack {
            Button("Toggle") { withAnimation { expanded.toggle() } }
            if expanded {
                DetailView()
                    // Slide/scale for most users; a simple fade when reduce-motion is on.
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
```

The principle: **honor the setting, don't ignore it.** A flashy spring animation you're proud of is, to a user with motion sensitivity, a reason to feel sick — and they told the system they don't want it. Reading `accessibilityReduceMotion` and adapting is respecting an explicit user preference, the same as honoring dark mode.

Two sibling environment values for the same kind of adaptation:

- **`\.accessibilityReduceTransparency`** — the user wants solid backgrounds instead of blurred/translucent ones. Swap a `.ultraThinMaterial` background for an opaque color when it's on.
- **`\.accessibilityDifferentiateWithoutColor`** — the user can't rely on color alone (color blindness); add a shape or icon or text cue alongside any color signal (next section).

And **`\.legibilityWeight`** — when the user has Bold Text on, you can bump your custom-drawn text weight to match. Standard text honors it automatically.

---

## 4. Color and contrast — don't signal with color alone

Two color rules, both about users who perceive color differently or need more contrast:

**Contrast.** Text must have sufficient contrast against its background to be readable — the **WCAG** ratios (4.5:1 for normal text, 3:1 for large text) are the standard bar, and the Accessibility Inspector's audit flags pairs that fail. Light-gray-on-white placeholder text is the classic failure: it looks elegant to a designer with perfect vision on a bright screen and is invisible to a user with low vision or in sunlight. Use the system's semantic colors (`.primary`, `.secondary`, `.label`) where you can — they're tuned for contrast and adapt to light/dark and increased-contrast mode.

**Never signal with color alone.** A red dot for "error" and a green dot for "ok" are *identical* to a red-green color-blind user (about 1 in 12 men). Any state you convey with color must *also* be conveyed with a shape, an icon, or text:

```swift
// BAD — color is the ONLY signal. Invisible to a color-blind user.
Circle().fill(isOnline ? .green : .red).frame(width: 10, height: 10)

// GOOD — color PLUS a shape/icon, so the signal survives color blindness.
Image(systemName: isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
    .foregroundStyle(isOnline ? .green : .red)
    .accessibilityLabel(isOnline ? "Online" : "Offline")  // and survives no-sight, via VoiceOver
```

The checkmark-vs-x distinction survives color blindness (the *shapes* differ), and the `accessibilityLabel` survives *no* sight (VoiceOver reads it). One status indicator, three channels — color, shape, and speech — so it works for everyone. When `accessibilityDifferentiateWithoutColor` is on, you can lean even harder into the shape/text cue. Color is an *enhancement* to a signal, never the *only* carrier of it.

---

## 5. Haptics — a non-visual feedback channel

**Haptics** — the taptic feedback you feel — are a feedback channel that works without sight *or* sound, and a polished confirmation for everyone. iOS gives you two tiers.

**Tier 1 — the simple generators**, for standard events. In SwiftUI, the cleanest path is `.sensoryFeedback`:

```swift
struct NoteListView: View {
    @State private var noteCount = 0

    var body: some View {
        List { /* ... */ }
            .toolbar {
                Button("Add", systemImage: "plus") { addNote(); noteCount += 1 }
            }
            // A crisp tap when a note is created — confirmation you can FEEL.
            .sensoryFeedback(.success, trigger: noteCount)
    }
}
```

Or the UIKit generators directly, which you **prepare** before the event so the haptic fires with no latency:

```swift
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.prepare()                 // warms up the Taptic Engine to avoid first-fire latency
// ...at the moment of the action:
impact.impactOccurred()

let notify = UINotificationFeedbackGenerator()
notify.notificationOccurred(.success)   // .success / .warning / .error
```

The `.prepare()` call matters: without it, the *first* haptic after an idle period lags noticeably while the Taptic Engine spins up. Prepare it just before the user is likely to trigger it (on the screen appearing, or on touch-down) so the feedback is instant.

**Tier 2 — `CHHapticEngine`**, for *custom* patterns — a specific rhythm, a ramp, a textured buzz — when the standard impacts aren't expressive enough:

```swift
import CoreHaptics

final class HapticsManager {
    private var engine: CHHapticEngine?

    func start() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    /// A two-tap custom pattern, e.g. to confirm a deliberate, important action.
    func playConfirm() {
        guard let engine else { return }
        let tap = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
        ], relativeTime: 0)
        let tap2 = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
        ], relativeTime: 0.12)
        if let pattern = try? CHHapticPattern(events: [tap, tap2], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }
}
```

Always check `capabilitiesForHardware().supportsHaptics` first — not every device has the Taptic Engine, and your code must degrade gracefully where it doesn't. And the discipline that keeps haptics *good*: **haptics confirm, they don't decorate.** A tap when a note is created, deleted, or an important action completes — meaningful. A buzz on every scroll tick or every keystroke — annoying noise that trains the user to ignore the feedback and drains the battery. Use haptics where they *mean* something, sparingly, and respect that some users turn system haptics off (your app must still work without them).

---

## 5.5 Testing every setting in previews — the cheap audit

You don't have to deploy and toggle Settings to *see* most of these failures — SwiftUI previews let you pin the accessibility environment, so you can eyeball a cell at AX5 or with reduce-motion right in Xcode. This is the cheapest possible audit and you should make it a habit for every cell you build:

```swift
#Preview("Default") {
    NoteRow(note: .sample)
}

#Preview("AX5 — does it clip?") {
    NoteRow(note: .sample)
        .environment(\.dynamicTypeSize, .accessibility5)   // largest size
}

#Preview("Reduce Transparency") {
    NoteRow(note: .sample)
        .environment(\.accessibilityReduceTransparency, true)
}

#Preview("Dark + bold") {
    NoteRow(note: .sample)
        .environment(\.legibilityWeight, .bold)
        .preferredColorScheme(.dark)
}
```

A row of previews pinned to the extreme settings turns "does this break at AX5?" from a deploy-and-poke chore into a glance. You catch the hard-coded-height clip, the unbalanced icon, the low-contrast text *while you're writing the view*, which is when it's a one-line fix instead of a bug report. The Dynamic Type override in particular — `.environment(\.dynamicTypeSize, .accessibility5)` — should be a reflex on every cell preview, because the AX5 clip is the single most common accessibility bug and the easiest to see if you just *look* at AX5.

Xcode's preview canvas also has a **Dynamic Type slider** and the **Variants** button (color scheme, orientation, Dynamic Type) so you can sweep the whole range without writing a preview per setting. Use whichever fits your flow; the point is that the audit is *available in the canvas*, seconds away, and there's no excuse for shipping a cell you never looked at large.

## 6. The footguns — what breaks for real users

The accessibility footguns, each named, shown, and fixed earlier, collected as the reviewer's checklist:

- **Fixed point size** (`.font(.system(size: 17))`) instead of a text style → ignores Dynamic Type, unreadable at AX5. *Fix: use `.body`/`.headline`/etc.*
- **Hard-coded frame height** on a text cell → clips at large sizes. *Fix: padding, not a fixed height; reflow to vertical at AX sizes.*
- **Fixed icon/padding next to scaling text** → unbalanced layout at AX5. *Fix: `@ScaledMetric`.*
- **Animation that ignores reduce-motion** → nauseating for motion-sensitive users. *Fix: read `accessibilityReduceMotion`, swap to a fade.*
- **Color-only state** (red/green dot) → invisible to color-blind users. *Fix: add a shape/icon and an `accessibilityLabel`.*
- **Low-contrast text** (light gray on white) → unreadable for low vision / in sunlight. *Fix: semantic colors, pass the contrast audit.*
- **Haptic on every tick** → noise. *Fix: haptics confirm meaningful actions only.*

Each is a *measurable* failure — the Inspector's audit catches the contrast, the small targets, and the missing labels; setting Dynamic Type to AX5 catches the clipping; turning on Reduce Motion catches the unsuppressed animation; the simulator's color filters catch the color-only signal. None of these is a matter of taste; each is a bug with a test that fails.

---

## 7. Putting it together — the inclusive-engineering checklist

The code-review checklist a senior reviewer applies to a screen:

- **Every text element uses a text style**, not a fixed point size — readable at every Dynamic Type size.
- **Cells reflow, don't clip, at AX5** — no hard-coded heights; horizontal cells go vertical at accessibility sizes.
- **`@ScaledMetric` for every fixed dimension next to text** — icons and spacing scale coherently.
- **Animations honor `accessibilityReduceMotion`** — flashy by default, calm when the user asked.
- **No color-only signaling** — every color cue has a shape/icon/text companion and an `accessibilityLabel`.
- **Contrast passes the audit** — semantic colors, no light-gray-on-white.
- **Haptics confirm meaningful actions only**, are `prepare()`d, check `supportsHaptics`, and degrade gracefully.
- **The accessibility tree is correct** (lecture 1) — labels, traits, merged cells, hidden decoration.
- **The audit reports zero issues, and the app is fully operable with VoiceOver + the screen curtain.**

---

## 7.5 The case for doing this, beyond "it's right"

It's worth being concrete about *why* this work pays, because "it's the right thing" — true as it is — doesn't always win a sprint-planning argument, and you should have the harder reasons ready:

- **It's the law in major markets.** The European Accessibility Act (in force from 2025) and the Americans with Disabilities Act (applied to apps in growing case law) make accessibility a legal requirement for many categories of app, not a nicety. Shipping an inaccessible app is, increasingly, shipping a liability.
- **App Review rejects for it.** Apple's guidelines and review process flag apps that mishandle accessibility — an unlabeled core flow, a control VoiceOver can't reach. A rejection costs you a release cycle; building it in costs you minutes per view.
- **It's table stakes for enterprise and government.** Procurement for large organizations and the public sector frequently *requires* accessibility conformance (Section 508, EN 301 549). An inaccessible app is disqualified from those contracts before anyone evaluates its features.
- **The audience is large.** A significant fraction of users have some accessibility need — low vision, color blindness, motion sensitivity, situational impairments (bright sunlight, one hand busy, a noisy room). Dynamic Type alone is used by a huge swath of *all* users, not a niche. "Accessible" overlaps heavily with "usable by everyone in real conditions."
- **It makes the app better for everyone.** Sufficient contrast helps the sighted user in sunlight. Haptic confirmation helps everyone know an action landed. A clean accessibility tree means your UI tests are stable. Good labels mean Siri and Shortcuts (Phase IV) can drive your app. Accessibility work is rarely *only* accessibility work.

So when the trade-off comes up, the answer isn't a moral appeal — it's "it's a legal requirement, an App Review gate, an enterprise-procurement requirement, and it's a few minutes per view if we build it in, versus a project if we bolt it on later." That's the senior framing, and it's why senior engineers don't treat accessibility as optional.

## 8. Recap

Lecture 1 made the app operable without sight; this lecture made it comfortable across the full range of human perception:

1. **Dynamic Type.** Text styles (never fixed point sizes), cells that reflow instead of clipping at AX5, and `@ScaledMetric` for the icon and spacing dimensions that must scale with the text.
2. **Motion and transparency.** Read `accessibilityReduceMotion` / `accessibilityReduceTransparency` and adapt — honor the user's explicit preference, don't override it with animation you're proud of.
3. **Color and contrast.** Sufficient contrast (the WCAG bar, the Inspector's audit), and never color *alone* — every signal also carries a shape, an icon, or text, so it survives color blindness and no sight.
4. **Haptics.** A non-visual feedback channel — `.sensoryFeedback` / `UIImpactFeedbackGenerator` for standard events, `CHHapticEngine` for custom patterns, `prepare()`d for instant fire, checking `supportsHaptics`, confirming meaningful actions only.

A one-screen reference of the APIs from this lecture:

- Text styles (`.body`, `.headline`, `.caption`) — never `.font(.system(size:))` — for Dynamic Type.
- `.dynamicTypeSize(...max:)` — cap the scale for a view where AX5 genuinely can't fit (use rarely).
- `dynamicTypeSize.isAccessibilitySize` + `AnyLayout` — reflow horizontal cells to vertical at AX sizes.
- `@ScaledMetric(relativeTo:)` — scale icon sizes and padding with the text.
- `\.accessibilityReduceMotion` — swap a slide/scale for a fade.
- `\.accessibilityReduceTransparency` — opaque backgrounds when requested.
- `\.accessibilityDifferentiateWithoutColor` — lean on shape/text cues.
- Semantic colors (`.primary`, `.secondary`, `.label`) + a shape/icon for every color signal.
- `.sensoryFeedback(.success, trigger:)` / `UIImpactFeedbackGenerator().prepare()` — confirm meaningful actions.
- `CHHapticEngine` (check `supportsHaptics`) — custom patterns when impacts aren't enough.
- `UINotificationFeedbackGenerator().notificationOccurred(.success/.warning/.error)` — outcome haptics.
- `.font(.custom(_:size:relativeTo:))` — a custom font that still scales with Dynamic Type.
- `.environment(\.dynamicTypeSize, .accessibility5)` in a `#Preview` — eyeball AX5 in the canvas.

Every one of these is *engineering*: a tool finds the failure, an API fixes it, a test confirms it. That's the week's thesis made concrete — accessibility is not charity, it's a quality axis you audit and fix to a measurable bar, exactly like performance.

A closing thought that ties the two lectures together. Lecture 1's accessibility tree and this lecture's Dynamic Type, motion, contrast, and haptics are not separate checklists — they're one idea seen from different angles: **your app must convey its meaning through more than one channel, so it survives the loss or limitation of any single channel.** Lose sight → the tree (VoiceOver) carries the meaning. Need bigger text → Dynamic Type carries it. Can't distinguish red from green → shape and text carry it. Can't tolerate motion → a fade carries the transition. Want confirmation without looking → a haptic carries it. Redundant channels are the whole game. A UI that puts all its meaning in one channel (pixels, at one size, in color, with motion) is fragile; a UI that carries its meaning across several is robust — and that robustness is exactly what "inclusive" means in engineering terms.

The exercises build a Dynamic-Type-safe cell and a reduce-motion-aware animation with haptics; the mini-project audits Notes v1 end to end, fixes every Inspector issue, and proves operability with the screen curtain on. Go make the app work for everyone — and *prove* it works with the screen black and the text at maximum.

Multiple channels for every meaning. One tool to audit. One bar to hit: zero issues, fully operable, readable at any size. That's inclusive engineering, and it's not optional — it's what finished looks like.
