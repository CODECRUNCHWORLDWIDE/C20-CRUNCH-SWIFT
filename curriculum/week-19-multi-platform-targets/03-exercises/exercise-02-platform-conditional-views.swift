// Exercise 2 — Platform-conditional views, the minimum-fork way
//
// Goal: Practice `#if os` DISCIPLINE. Some adaptations genuinely need a platform
//       branch (a macOS-only window minimum size, an iOS-only haptic). The skill
//       is doing it with the SMALLEST, most LOCALIZED fork — an isolated
//       ViewModifier or helper — never a forked `body`, and never inside the
//       shared domain logic. This file shows the right shape and gives you a
//       test that the shared logic stays branch-free.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Drop this into a Multiplatform SwiftUI app target (iOS + macOS, ideally
// watchOS too). The VIEWS render per platform; the SHARED logic at the bottom
// is tested with Swift Testing and must compile identically everywhere.
//
//   1. Add to a Multiplatform app target with iOS, macOS (and optionally
//      watchOS) destinations.
//   2. Build for each destination — the #if os branches compile the right code.
//   3. Run the test suite (Cmd-U) to confirm the shared logic is branch-free.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings on iOS and macOS (and watchOS if added).
//   [ ] Every #if os is isolated in a NAMED modifier/helper, never in a `body`.
//   [ ] The shared `NoteFormatter` logic has ZERO platform branches and the
//       test proves it returns the same result everywhere.
//   [ ] You can name, for each #if os in this file, why the API is genuinely
//       platform-specific (and couldn't be an adaptive container instead).
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import SwiftUI

// ----------------------------------------------------------------------------
// 1. The view. Note: the BODY has no #if os. Platform touches are isolated in
//    named modifiers below, applied with a clean call site.
// ----------------------------------------------------------------------------

struct NoteEditorView: View {
    @State private var text: String = ""
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit note").font(.headline)
            TextField("Body", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                onSave()
                triggerSaveFeedback()        // platform-specific feedback, isolated below
            }
            .keyboardShortcut("s", modifiers: .command)   // ⌘S on Mac; inert elsewhere — no #if os needed
        }
        .padding()
        .platformWindowSizing()              // macOS-only min size, isolated in a modifier
    }
}

// ----------------------------------------------------------------------------
// 2. The isolated platform forks. Each is a NAMED, SINGLE-PURPOSE place. This is
//    the scalpel: one small branch, not a forked view.
// ----------------------------------------------------------------------------

extension View {
    /// macOS windows want a minimum size; other platforms don't have resizable
    /// windows in the same way. ONE branch, named, reusable.
    func platformWindowSizing() -> some View {
        modifier(PlatformWindowSizing())
    }
}

private struct PlatformWindowSizing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 480, minHeight: 320)
        #else
        content   // iOS/watchOS/visionOS: no fixed window minimum here
        #endif
    }
}

/// Haptic feedback exists on iOS (and watchOS), not macOS. The branch is here,
/// in ONE function, not smeared through the view.
@MainActor
func triggerSaveFeedback() {
    #if os(iOS)
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    #elseif os(watchOS)
    // WKInterfaceDevice.current().play(.success)  // watch haptics, if this target includes watchOS
    #else
    // macOS: no haptic; could NSSound.beep() if desired, or nothing.
    #endif
}

// ----------------------------------------------------------------------------
// 3. The SHARED logic. This has NO #if os, period. It would live in NotesCore.
//    The test proves it's identical on every platform — same input, same output.
// ----------------------------------------------------------------------------

enum NoteFormatter {
    /// Pure formatting — the answer does NOT depend on the platform, so no branch.
    static func preview(_ body: String, maxLength: Int = 40) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<endIndex]) + "…"
    }
}

#if canImport(Testing)
import Testing

struct NoteFormatterTests {
    @Test("preview truncates long bodies with an ellipsis")
    func truncates() {
        let long = String(repeating: "a", count: 100)
        let result = NoteFormatter.preview(long, maxLength: 10)
        #expect(result == "aaaaaaaaaa…")
        #expect(result.count == 11)   // 10 chars + the ellipsis
    }

    @Test("preview leaves short bodies untouched")
    func keepsShort() {
        #expect(NoteFormatter.preview("hi") == "hi")
    }

    @Test("preview trims surrounding whitespace first")
    func trims() {
        #expect(NoteFormatter.preview("   spaced   ") == "spaced")
    }
}
#endif

// ----------------------------------------------------------------------------
// WHY each #if os here is legitimate (write your own reason before reading):
//
//   - platformWindowSizing: macOS has resizable windows with a meaningful
//     minimum; iOS is full-screen scenes. This is a genuine API/behaviour
//     difference, NOT something an adaptive container expresses, so it earns a
//     branch — isolated in one ViewModifier.
//
//   - triggerSaveFeedback: UINotificationFeedbackGenerator is iOS-only;
//     macOS has no equivalent haptic. Platform-exclusive API -> branch, in one
//     function.
//
//   - NoteFormatter.preview: the result is identical on every platform, so it
//     gets ZERO branches. If you ever feel the urge to #if os it, the logic is
//     wrong — formatting doesn't depend on the device.
//
//   - .keyboardShortcut needed NO #if os: it's inert where there's no keyboard.
//     Prefer free-adapting modifiers over branches whenever they exist.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `#if os(iOS)` / `os(macOS)` / `os(watchOS)` / `os(visionOS)` are the four
//   you'll use. `#if targetEnvironment(macCatalyst)` distinguishes Catalyst.
//
// - If a build fails on macOS with "UINotificationFeedbackGenerator unresolved,"
//   your haptic call isn't inside an `#if os(iOS)` — UIKit haptics don't exist
//   on Mac. That failure is the lesson: the branch is REQUIRED, so isolate it.
//
// - Don't put the #if os in the `body`. If you find yourself branching the
//   whole view, extract the differing part into a named modifier or helper and
//   branch THERE. The body should read clean on every platform.
//
// - The TextField `axis: .vertical` is iOS 16+/macOS 13+. Raise the deployment
//   target if it doesn't resolve.
//
// - The shared `NoteFormatter` must compile in a package with NO UIKit/AppKit
//   import. If your "shared" code needs `#if os`, it isn't shared — it's shell.
//
// ----------------------------------------------------------------------------
