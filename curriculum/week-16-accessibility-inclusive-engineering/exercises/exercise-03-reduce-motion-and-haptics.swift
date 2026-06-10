// Exercise 3 — Reduce Motion + haptics, respecting the user's settings
//
// Goal: Two inclusive-engineering reflexes. (1) Read \.accessibilityReduceMotion
//       and swap a slide/scale animation for a gentle fade when the user has
//       Reduce Motion on — honoring an explicit preference instead of overriding
//       it. (2) Add haptic confirmation on a deliberate action with
//       .sensoryFeedback / UIImpactFeedbackGenerator — feedback you can FEEL,
//       prepared for instant fire, used only where it MEANS something.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into a SwiftUI app target (iOS 17+/macOS 14+). Show `MotionHapticsDemo` as
// the root. Toggle Settings ▸ Accessibility ▸ Motion ▸ Reduce Motion to see the
// animation change. Haptics need a real DEVICE (the Simulator has no Taptic
// Engine) — the code is correct either way, you just won't FEEL it on Simulator.
//
//   1. Add this file; run on a device for the haptics.
//   2. Tap "Reveal" with Reduce Motion OFF — it slides + scales in.
//   3. Turn Reduce Motion ON (Settings) — tap "Reveal" — it now FADES in.
//   4. Tap "Confirm" — feel the success haptic (on a device).
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] The reveal animation is a slide/scale normally and a FADE when
//       accessibilityReduceMotion is true.
//   [ ] A confirmed action fires a haptic (.sensoryFeedback or a prepared
//       UIImpactFeedbackGenerator).
//   [ ] The haptic code checks for / degrades gracefully without a Taptic Engine.
//   [ ] You can explain why honoring reduce-motion matters (it's an explicit
//       user preference, not a guess).
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import SwiftUI
import UIKit

// ----------------------------------------------------------------------------
// PART 1 — Reduce Motion: adapt the transition to the user's setting.
// ----------------------------------------------------------------------------

struct RevealSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 16) {
            Button(shown ? "Hide" : "Reveal") {
                // Use no/lighter animation when reduce-motion is on.
                withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.4)) {
                    shown.toggle()
                }
            }
            .buttonStyle(.borderedProminent)

            if shown {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.tint.opacity(0.2))
                    .frame(height: 120)
                    .overlay(Text("Revealed content").font(.headline))
                    // Slide + scale for most users; a plain fade when reduce-motion is on.
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.9).combined(with: .move(edge: .bottom)).combined(with: .opacity)
                    )
            }
        }
    }
}

// ----------------------------------------------------------------------------
// PART 2a — Simple haptics via SwiftUI's .sensoryFeedback (the modern path).
// ----------------------------------------------------------------------------

struct ConfirmWithSensoryFeedback: View {
    @State private var confirmCount = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Confirmed \(confirmCount) times").font(.subheadline)
            Button("Confirm (sensoryFeedback)") { confirmCount += 1 }
                .buttonStyle(.bordered)
        }
        // A success haptic each time confirmCount changes. The trigger value
        // drives it; SwiftUI handles preparation and respects user settings.
        .sensoryFeedback(.success, trigger: confirmCount)
    }
}

// ----------------------------------------------------------------------------
// PART 2b — UIKit generator, PREPARED for instant fire (no first-tap latency).
// ----------------------------------------------------------------------------

struct ConfirmWithGenerator: View {
    // Hold the generator so we can prepare() it before the user is likely to tap.
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button("Confirm (UIKit, prepared)") {
            impact.impactOccurred()        // instant, because we prepared on appear
        }
        .buttonStyle(.bordered)
        .onAppear {
            // Warm up the Taptic Engine so the first haptic has no latency.
            impact.prepare()
        }
    }
}

// ----------------------------------------------------------------------------
// The demo screen.
// ----------------------------------------------------------------------------

struct MotionHapticsDemo: View {
    var body: some View {
        VStack(spacing: 40) {
            RevealSection()
            Divider()
            ConfirmWithSensoryFeedback()
            ConfirmWithGenerator()
        }
        .padding()
    }
}

#Preview { MotionHapticsDemo() }

#Preview("Reduce Motion ON") {
    MotionHapticsDemo()
        .environment(\.accessibilityReduceMotion, true)
}

// ----------------------------------------------------------------------------
// WHY honoring reduce-motion matters (write it before reading):
//
//   Reduce Motion is an EXPLICIT user preference set in Settings, often because
//   animation causes the user nausea, dizziness, or disorientation (vestibular
//   conditions). Ignoring it and playing your slide/scale animation anyway
//   overrides a medical accommodation the user deliberately requested. Reading
//   \.accessibilityReduceMotion and swapping to a fade respects that choice the
//   same way you'd respect dark mode — it's not your call to override.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `.transition(reduceMotion ? .opacity : <fancy>)` is the cleanest swap. Make
//   sure the insertion is wrapped in `withAnimation` (the Button action) or the
//   transition won't run.
//
// - `.sensoryFeedback(_:trigger:)` fires when the `trigger` value CHANGES. Drive
//   it with a counter or a state value that changes on the action.
//
// - `impact.prepare()` matters: without it, the FIRST haptic after an idle
//   period lags while the Taptic Engine spins up. Prepare on appear or touch-down.
//
// - Haptics are SILENT on the Simulator (no Taptic Engine). The code is correct;
//   run on a device to feel it. For custom CHHapticEngine patterns, always check
//   `CHHapticEngine.capabilitiesForHardware().supportsHaptics` first.
//
// - Don't fire a haptic on every state change — only on actions that MEAN
//   something (confirm, create, delete). A haptic on every keystroke is noise.
//
// ----------------------------------------------------------------------------
