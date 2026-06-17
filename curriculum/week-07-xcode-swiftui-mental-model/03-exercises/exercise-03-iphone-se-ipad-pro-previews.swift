// Exercise 3 — iPhone SE & iPad Pro 13-inch Previews
//
// Goal: Render ONE view across two very different device classes — the 4.7"
//       iPhone SE (3rd gen) and the 13" iPad Pro (M4) — using multiple #Preview
//       blocks, and adapt the layout with a size class so it reads correctly on
//       BOTH. This is the propose/choose/place model under two wildly different
//       proposed sizes.
//
// Estimated time: 40 minutes.
//
// HOW TO RUN THIS FILE
//
//   New Xcode project: File > New > Project > iOS > App ("ResponsiveStats",
//   SwiftUI, Swift, storage None). Replace ContentView.swift's contents with
//   this file's contents. Open the Canvas (Opt-Cmd-Return). You will see the
//   named previews; each can be set to a specific device in the Canvas device
//   picker, and the code below also pins devices explicitly.
//
//   To run on a specific simulator, pick it from the run-destination menu in
//   the toolbar (e.g. "iPhone SE (3rd generation)" or "iPad Pro 13-inch (M4)")
//   and press Cmd-R.
//
// WHAT TO INTERNALISE
//
//   - One view, two devices. The same `body` lays out differently because the
//     PROPOSED size differs: a phone proposes ~375pt of width, the iPad
//     proposes ~1000pt+.
//   - @Environment(\.horizontalSizeClass) tells you whether you're in a
//     .compact (phone portrait) or .regular (iPad) horizontal environment.
//     Use it to switch between a single column and a multi-column grid.
//   - A view that "looks right on the simulator you happen to have booted" is
//     not done. Three device classes, two appearances, largest Dynamic Type.
//     This exercise drills the device half of that promise.

import SwiftUI

// ----------------------------------------------------------------------------
// A reusable stat tile.
// ----------------------------------------------------------------------------

struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)   // shrink rather than clip on tiny widths
                .lineLimit(1)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

// ----------------------------------------------------------------------------
// The adaptive dashboard. On a COMPACT width (iPhone portrait) it stacks the
// tiles in a single column. On a REGULAR width (iPad) it uses an adaptive grid
// so the tiles flow into multiple columns and use the extra space.
// ----------------------------------------------------------------------------

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let stats: [(title: String, value: String, symbol: String, tint: Color)] = [
        ("Notes", "128", "note.text", .blue),
        ("Tags", "14", "tag.fill", .green),
        ("Pinned", "3", "pin.fill", .orange),
        ("Archived", "47", "archivebox.fill", .purple),
        ("Shared", "9", "person.2.fill", .pink),
        ("Drafts", "6", "pencil.and.outline", .teal),
    ]

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    // On iPad, let tiles be at least 220pt wide and flow into as many columns
    // as fit. On iPhone, a single flexible column.
    private var columns: [GridItem] {
        if isRegularWidth {
            [GridItem(.adaptive(minimum: 220), spacing: 16)]
        } else {
            [GridItem(.flexible(), spacing: 16)]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Overview")
                    .font(isRegularWidth ? .largeTitle.bold() : .title.bold())

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(stats, id: \.title) { stat in
                        StatTile(
                            title: stat.title,
                            value: stat.value,
                            symbol: stat.symbol,
                            tint: stat.tint
                        )
                    }
                }
            }
            // Constrain content width on huge iPad screens so tiles don't
            // become absurdly wide; center the column group.
            .frame(maxWidth: isRegularWidth ? 980 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// ----------------------------------------------------------------------------
// Previews — the same view, two device classes, both appearances.
// ----------------------------------------------------------------------------

#Preview("iPhone SE") {
    ContentView()
}

#Preview("iPad Pro 13-inch") {
    ContentView()
}

#Preview("iPad Pro 13-inch · Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

// In the Canvas device picker, set "iPhone SE" preview to
// "iPhone SE (3rd generation)" and the iPad previews to
// "iPad Pro 13-inch (M4)". The code adapts to whichever the system proposes.

// ----------------------------------------------------------------------------
// YOUR TURN
// ----------------------------------------------------------------------------
//
// 1. Run on the iPhone SE (3rd generation) simulator. Confirm the tiles stack
//    in a single column and nothing clips, even with six tiles.
//
// 2. Run on the iPad Pro 13-inch (M4) simulator. Confirm the tiles flow into
//    multiple columns (the .adaptive grid) and the content column is capped at
//    980pt so the tiles don't stretch to absurd widths.
//
// 3. ROTATE the iPhone to landscape (Cmd-Right-Arrow in the simulator). Note
//    that an iPhone in landscape is STILL horizontalSizeClass == .compact for
//    most models, so it keeps the single column. Then rotate the iPad — it
//    stays .regular. Explain in a comment why size class, not raw width, is the
//    right signal to branch on.
//
// 4. Add a 7th and 8th tile to `stats`. Confirm BOTH devices still render
//    correctly with no layout change needed — the grid absorbs them. That is
//    the payoff of a size-adaptive layout over hard-coded device checks.
//
// 5. STRETCH: replace the `isRegularWidth ? .largeTitle : .title` ternary with
//    a `ViewThatFits` around the title so the largest font that fits is chosen
//    automatically. Note where ViewThatFits helps and where size class is still
//    the clearer tool.
//
// ----------------------------------------------------------------------------
// ACCEPTANCE CRITERIA
// ----------------------------------------------------------------------------
//
//   [ ] Build Succeeded with zero warnings.
//   [ ] On iPhone SE (3rd gen): single-column layout, no clipping, no
//       horizontal scroll, all six tiles visible by scrolling vertically.
//   [ ] On iPad Pro 13-inch (M4): multi-column adaptive grid, content capped at
//       980pt and centered, uses the extra width sensibly.
//   [ ] The layout branches on @Environment(\.horizontalSizeClass), NOT on a
//       hard-coded device name or a raw pixel width.
//   [ ] Adding more tiles requires no layout code change.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck >10 min)
// ----------------------------------------------------------------------------
//
//   - GridItem(.adaptive(minimum: 220)) is the single most useful grid item:
//     it packs as many columns of >= 220pt as fit, and reflows on resize.
//   - minimumScaleFactor(0.6) on the big number lets a long value shrink to fit
//     a narrow tile instead of truncating with an ellipsis. Prefer scaling over
//     truncation for short, important values.
//   - horizontalSizeClass is .compact on iPhone (both orientations, most
//     models) and .regular on iPad. It is the correct, device-agnostic signal —
//     a future foldable or a Split View window also reports .compact when
//     narrow, and your layout will already be right.
//   - To see both at once, keep multiple #Preview blocks pinned; the Canvas
//     renders them stacked.
