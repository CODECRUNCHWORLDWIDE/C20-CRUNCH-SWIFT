// Exercise 2 — A Dynamic-Type-safe list cell
//
// Goal: Build a list cell that renders CORRECTLY from the default text size all
//       the way up to AX5 (the largest accessibility size) — no clipping, no
//       truncation, balanced icon and spacing. The tools: semantic text styles
//       (scale for free), @ScaledMetric (scale the non-text dimensions), and a
//       reflow-to-vertical layout at accessibility sizes. Plus previews pinned
//       to AX5 that PROVE it doesn't break.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into a SwiftUI app target (iOS 17+/macOS 14+). Show `NoteCellDemo` as the
// root, or just open the #Previews in the canvas. The whole exercise is visible
// in the preview canvas — the AX5 preview is the test.
//
//   1. Add this file; open the canvas.
//   2. Compare the "Default" and "AX5" previews. The BAD cell clips at AX5;
//      the GOOD cell reflows and stays readable.
//   3. Drag the canvas's Dynamic Type slider through the whole range and watch.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] `GoodNoteCell` renders without clipping or truncation at AX5.
//   [ ] It uses text STYLES (not fixed point sizes) and @ScaledMetric for the
//       icon/spacing dimensions.
//   [ ] It reflows from horizontal to vertical at accessibility sizes.
//   [ ] The AX5 #Preview shows the cell intact (no clipped text).
//   [ ] You can explain why a hard-coded frame height breaks at AX5.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import SwiftUI

// ----------------------------------------------------------------------------
// A sample model.
// ----------------------------------------------------------------------------

struct Note: Identifiable {
    let id = UUID()
    var title: String
    var preview: String
    var tagCount: Int

    static let sample = Note(
        title: "Quarterly planning notes and the long tail of follow-ups",
        preview: "We agreed to revisit the roadmap after the offsite and circle back on staffing.",
        tagCount: 3
    )
}

// ----------------------------------------------------------------------------
// THE BAD CELL — fixed point size + hard-coded height. Clips at AX5.
// ----------------------------------------------------------------------------

struct BadNoteCell: View {
    let note: Note
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 16))            // FROZEN — ignores Dynamic Type
            VStack(alignment: .leading) {
                Text(note.title).font(.system(size: 17))   // FROZEN
                Text(note.preview).font(.system(size: 13)) // FROZEN
            }
        }
        .frame(height: 44)                          // HARD-CODED — clips the text at AX5
    }
}

// ----------------------------------------------------------------------------
// THE GOOD CELL — text styles, @ScaledMetric, reflow at AX sizes, no fixed height.
// ----------------------------------------------------------------------------

struct GoodNoteCell: View {
    let note: Note
    @Environment(\.dynamicTypeSize) private var typeSize

    // Scale the icon and spacing WITH the text, relative to the .headline style.
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 10

    var body: some View {
        // At accessibility sizes, stack vertically so text gets full width.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .top, spacing: spacing))

        layout {
            Image(systemName: "note.text")
                .font(.system(size: iconSize))       // scales with the text
                .foregroundStyle(.tint)
                .accessibilityHidden(true)           // decorative; the title carries the meaning

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)                 // scales for free
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)   // let it wrap at AX sizes
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Text("\(note.tagCount) tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)                        // PADDING, not a fixed height — grows with text
        .accessibilityElement(children: .combine)     // one VoiceOver stop per cell
    }
}

// ----------------------------------------------------------------------------
// A demo list to feel it in a real List context.
// ----------------------------------------------------------------------------

struct NoteCellDemo: View {
    let notes = (0..<8).map { _ in Note.sample }
    var body: some View {
        List(notes) { GoodNoteCell(note: $0) }
    }
}

// ----------------------------------------------------------------------------
// PREVIEWS — the AX5 preview is the TEST. The bad cell clips; the good one doesn't.
// ----------------------------------------------------------------------------

#Preview("Good — default") {
    List { GoodNoteCell(note: .sample) }
}

#Preview("Good — AX5 (must not clip)") {
    List { GoodNoteCell(note: .sample) }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Bad — AX5 (clips!)") {
    List { BadNoteCell(note: .sample) }
        .environment(\.dynamicTypeSize, .accessibility5)
}

// ----------------------------------------------------------------------------
// WHY a hard-coded frame height breaks at AX5 (write it before reading):
//
//   `.frame(height: 44)` pins the cell to 44 points regardless of its content.
//   At AX5 the title alone needs far more than 44 points of vertical space, so
//   the text is CLIPPED to fit the frame — the user sees a cut-off line. Using
//   padding instead of a fixed height lets the cell size to its content, so it
//   grows as the text grows. Fixed dimensions and Dynamic Type are in direct
//   conflict; let content drive the size.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `typeSize.isAccessibilitySize` is true for AX1–AX5. Use it to switch the
//   layout (AnyLayout) and to drop lineLimit so text can wrap fully.
//
// - `@ScaledMetric(relativeTo: .headline) var iconSize: CGFloat = 18` scales the
//   18pt base value along the .headline curve. Without `relativeTo:`, it scales
//   along .body — fine, but tie it to the style it sits next to for the best fit.
//
// - `AnyLayout` lets you swap HStack/VStack without duplicating the children.
//   `AnyLayout(VStackLayout(...))` vs `AnyLayout(HStackLayout(...))`.
//
// - If the GOOD cell still truncates at AX5, you left a `lineLimit` on or a fixed
//   width somewhere. Drop limits at accessibility sizes and never fix the height.
//
// - The Xcode canvas has a Dynamic Type slider (and a Variants button) so you can
//   sweep sizes without writing a preview per size. The AX5 preview is the one
//   that matters most.
//
// ----------------------------------------------------------------------------
