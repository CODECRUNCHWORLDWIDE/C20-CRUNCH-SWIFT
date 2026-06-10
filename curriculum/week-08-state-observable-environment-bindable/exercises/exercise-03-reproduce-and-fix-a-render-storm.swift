// Exercise 3 — Reproduce and fix a render storm
//
// Goal: Reproduce a re-render storm caused by misplaced @State and over-broad
//       row inputs, SEE it with Self._printChanges() and a render counter,
//       then fix it and verify the count drops to the minimum.
//
// Estimated time: 50 minutes.
//
// HOW TO RUN THIS FILE
//
// 1. Create a fresh iOS App project in Xcode 16+ (SwiftUI, iOS 17+ deployment).
// 2. Replace the generated ContentView.swift with the contents of THIS FILE.
// 3. Point the @main App at `StormToggleRoot` (or rename it to ContentView).
// 4. Run on an iPhone simulator. Open the console.
//
// THE EXPERIMENT
//
//   This file ships TWO screens behind a Picker:
//     - "Stormy"  — the broken version. Type into the search field and watch
//                   EVERY visible row print to the console on EACH keystroke.
//     - "Calm"    — the fixed version. Type and watch only the parent recompute;
//                   rows do not re-render their text on a keystroke.
//
//   Toggle between them and compare the console output for the SAME action
//   (typing one character). The difference is the entire lesson of Lecture 2.
//
// ACCEPTANCE CRITERIA
//
//   [ ] You ran "Stormy" and saw N rows print on a single keystroke.
//   [ ] You ran "Calm" and saw the row bodies NOT print on a keystroke that
//       does not change a row's own data.
//   [ ] You can name the two causes fixed here: over-broad row input (Cause B)
//       and high-frequency state sharing a body with an expensive tree (Cause C).
//   [ ] Build has zero warnings under iOS 17+ strict concurrency.
//
// This file is complete and runnable — no TODOs. The point is to OBSERVE the
// difference, then read the "WHY" notes at the bottom.

import SwiftUI
import Observation

// ----------------------------------------------------------------------------
// Shared model + data
// ----------------------------------------------------------------------------

struct Item: Identifiable, Hashable {
    let id = UUID()
    var name: String
}

@Observable
final class Catalog {
    var items: [Item]
    init(count: Int) {
        items = (1...count).map { Item(name: "Item \($0)") }
    }
}

// A render counter that lives OUTSIDE SwiftUI's dependency graph (Lecture 2 §2.1).
final class RowRenderCounter {
    private var counts: [UUID: Int] = [:]
    let screen: String
    init(screen: String) { self.screen = screen }
    func tick(_ id: UUID) {
        counts[id, default: 0] += 1
        print("[\(screen) row \(id.uuidString.prefix(4))] render #\(counts[id]!)")
    }
}

// ----------------------------------------------------------------------------
// Toggle root — switch between the two screens to compare.
// ----------------------------------------------------------------------------

enum Screen: String, CaseIterable, Identifiable {
    case stormy = "Stormy"
    case calm = "Calm"
    var id: Self { self }
}

struct StormToggleRoot: View {
    @State private var screen: Screen = .stormy
    @State private var catalog = Catalog(count: 30)

    var body: some View {
        VStack(spacing: 0) {
            Picker("Screen", selection: $screen) {
                ForEach(Screen.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            switch screen {
            case .stormy: StormyScreen(catalog: catalog)
            case .calm:   CalmScreen(catalog: catalog)
            }
        }
    }
}

// ----------------------------------------------------------------------------
// STORMY — the broken version.
//
// Two defects:
//   Cause C: `searchText` is @State on the SAME view that builds the List, so a
//            keystroke recomputes the whole body including the list-building code.
//   Cause B: StormyRow takes the WHOLE items array (to show a count), so every
//            row is coupled to every item — and the row body runs on each render.
// ----------------------------------------------------------------------------

struct StormyScreen: View {
    let catalog: Catalog
    @State private var searchText = ""
    @State private var counter = RowRenderCounter(screen: "Stormy")

    var body: some View {
        let _ = Self._printChanges()
        VStack(spacing: 0) {
            TextField("Search", text: $searchText)        // Cause C: high-frequency @State here
                .textFieldStyle(.roundedBorder)
                .padding()

            List(filtered) { item in
                StormyRow(item: item, allItems: catalog.items, counter: counter)  // Cause B
            }
        }
    }

    private var filtered: [Item] {
        searchText.isEmpty ? catalog.items
            : catalog.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct StormyRow: View {
    let item: Item
    let allItems: [Item]      // Cause B: takes the whole array just to show a count
    let counter: RowRenderCounter

    var body: some View {
        let _ = counter.tick(item.id)
        HStack {
            Text(item.name)
            Spacer()
            Text("of \(allItems.count)").foregroundStyle(.secondary)
        }
    }
}

// ----------------------------------------------------------------------------
// CALM — the fixed version.
//
// Fix C: extract the search field and the results list into their own views,
//        so a keystroke re-renders the (cheap) search field and the parent body,
//        but the ResultsList only re-renders when its `items` input changes.
// Fix B: CalmRow takes ONLY its own item plus a small Int count, not the array.
// ----------------------------------------------------------------------------

struct CalmScreen: View {
    let catalog: Catalog
    @State private var searchText = ""
    @State private var counter = RowRenderCounter(screen: "Calm")

    var body: some View {
        let _ = Self._printChanges()
        VStack(spacing: 0) {
            SearchField(text: $searchText)                 // Fix C: extracted control
                .padding()
            ResultsList(items: filtered, total: catalog.items.count, counter: counter)  // Fix C
        }
    }

    private var filtered: [Item] {
        searchText.isEmpty ? catalog.items
            : catalog.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        let _ = Self._printChanges()
        TextField("Search", text: $text).textFieldStyle(.roundedBorder)
    }
}

struct ResultsList: View {
    let items: [Item]
    let total: Int
    let counter: RowRenderCounter

    var body: some View {
        let _ = Self._printChanges()
        List(items) { item in
            CalmRow(item: item, total: total, counter: counter)  // Fix B: minimal inputs
        }
    }
}

struct CalmRow: View {
    let item: Item        // Fix B: only its own data...
    let total: Int        // ...plus a small scalar, not the whole array
    let counter: RowRenderCounter

    var body: some View {
        let _ = counter.tick(item.id)
        HStack {
            Text(item.name)
            Spacer()
            Text("of \(total)").foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StormToggleRoot()
}

// ----------------------------------------------------------------------------
// WHY THE CALM VERSION IS CALM (read this — it is the lesson)
//
//  - In STORMY, `searchText` and the List live in the same `body`. A keystroke
//    invalidates StormyScreen.body, which re-runs the list-building code, which
//    re-creates the row views. Because StormyRow ALSO takes the whole `allItems`
//    array, every row is re-evaluated. Result: every visible row's body runs on
//    every keystroke — the storm. Watch the console fill with row ticks.
//
//  - In CALM, the search field is its own view (SearchField). A keystroke
//    re-renders SearchField (cheap) and CalmScreen.body (which recomputes the
//    `filtered` array). But ResultsList only re-renders if its `items` input is
//    a DIFFERENT value than last frame. And CalmRow takes only its own `item`
//    plus a small `total` Int — so an unchanged row, whose `item` is identical,
//    is not re-evaluated. Type a character that does not change the result set
//    and the row bodies do NOT print. Narrow the query so the result set shrinks
//    and only the rows that actually change membership update.
//
//  - The two structural levers: (1) minimise a view's inputs (Fix B), and
//    (2) extract expensive subtrees away from high-frequency state (Fix C).
//    Together they turn an N-rows-per-keystroke storm into surgical updates.
//
//  EXPERIMENT TO TRY:
//    Type the same single character on each screen and count the row ticks in
//    the console. Stormy prints ~one tick per visible row PER keystroke. Calm
//    prints zero row ticks for a keystroke that does not change the result set.
// ----------------------------------------------------------------------------
