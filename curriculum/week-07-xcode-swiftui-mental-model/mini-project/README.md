# Mini-Project — "Hello, Notes": your first SwiftUI app

> Build a single-screen SwiftUI app that lists a set of hard-coded notes and renders *correctly* on iPhone SE (3rd gen) and iPad Pro 13-inch (M4), in light and dark mode, at the largest accessibility Dynamic Type size. No state, no navigation, no persistence — just a view hierarchy you can defend, modifier by modifier, and a screen that survives all six device/appearance/text-size combinations. This is the foundation app for the rest of Phase II: Week 8 makes it mutable, Week 9 adds navigation, Week 10 adds SwiftData. Keep the repo.

**Estimated time:** ~8.5 hours (split across Thursday, Friday, and Saturday in the suggested schedule).

---

## Why this project, why now

"Hello, Notes" is deliberately small. There is no clever algorithm, no concurrency, no networking — you have already done all of that on Linux in Phase I. The entire difficulty of this project is **describing a UI as a function of (static) data and making it robust across the device matrix.** That is the one skill Week 7 exists to build, and it is the skill everything in Phase II compounds on.

The data is hard-coded on purpose. This week you learn to *describe* a UI before you learn to *drive* it (Week 8). Every note lives in an array literal in source. Nothing the user does changes the data. When you reach Week 8 you will replace that array with an `@Observable` `NotesStore` and the list will become live — but the view hierarchy you build this week will barely change, because you will have built it as a pure function of its inputs from the start. That is the payoff: a correct mental model now saves you a rewrite later.

This is the **Phase II milestone-app, episode 1.** You will carry the same repository forward:

- **Week 7 (this week):** static list, light/dark, Dynamic Type, two device classes.
- **Week 8:** `@Observable` `NotesStore`, add/edit/delete, edit-in-a-sheet.
- **Week 9:** `NavigationStack` on iPhone, `NavigationSplitView` on iPad/Mac, deep links.
- **Week 10:** SwiftData persistence, a `Tag` model, queries by tag.
- **Week 12:** "Notes v1" — the Phase II integration project, search-as-you-type, the lot.

So build it cleanly. You will live in this codebase for six weeks.

---

## What you will build

A single-screen iOS app, `HelloNotes`, that:

1. Shows a **header** with the app title ("Notes") and a subtitle showing the note count (e.g. "6 notes").
2. Renders a **scrolling list of note cards**, each card built from the `NoteCard` component (the Week 7 challenge component, or your own equivalent). Each card shows: a leading SF Symbol, a title, a multi-line body preview, and a trailing category badge.
3. Sources its notes from a **hard-coded array** of a `Note` value type — at least **six** notes, with varied title lengths, body lengths, and categories, so the layout is exercised by realistic content.
4. **Adapts to light and dark mode** automatically, via semantic and asset-catalog colours, with **zero** `if colorScheme == .dark` branching that chooses a colour.
5. **Survives Dynamic Type up to `.accessibility5`** with no clipping and no title/badge truncation — cards reflow when the text is huge.
6. **Renders correctly on iPhone SE (3rd gen) and iPad Pro 13-inch (M4)** — single column on the phone, a sensible multi-column or width-capped layout on the iPad.

That is the whole app. One screen. No buttons that do anything yet (an "Edit" affordance may be present but inert — it is wired for real in Week 8). The bar is *correctness across the matrix*, not feature count.

---

## Project shape

You ship **one Xcode project**, `HelloNotes`, with this source layout under the app target:

```
HelloNotes/
├── HelloNotesApp.swift          // @main App + WindowGroup
├── ContentView.swift            // the single screen: header + list
├── Models/
│   └── Note.swift               // the Note value type + sample data
├── Views/
│   ├── NoteCard.swift           // the reusable card (image, title, body, badge)
│   ├── NoteListHeader.swift     // title + note count
│   └── CategoryBadge.swift      // the trailing pill
└── Assets.xcassets/
    ├── AccentColor.colorset
    ├── AppIcon.appiconset
    └── CardBackground.colorset  // light + dark variants
```

No Swift Package, no extra targets (the test target Xcode generates may stay empty this week). Keep it a plain SwiftUI app.

---

## The data model

The note is a plain value type. No `@Model`, no `class`, no `Identifiable` strictly required this week (it becomes required when you put it in a `ForEach` with stable identity — and you should add it now, because it costs nothing and Week 8 needs it):

```swift
import SwiftUI

struct Note: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let symbol: String          // SF Symbol name, e.g. "note.text"
    let category: Category
}

enum Category: String, CaseIterable {
    case work = "Work"
    case personal = "Personal"
    case ideas = "Ideas"
    case errands = "Errands"

    var tint: Color {
        switch self {
        case .work: .blue
        case .personal: .green
        case .ideas: .purple
        case .errands: .orange
        }
    }

    var symbol: String {
        switch self {
        case .work: "briefcase.fill"
        case .personal: "person.fill"
        case .ideas: "lightbulb.fill"
        case .errands: "cart.fill"
        }
    }
}

extension Note {
    static let samples: [Note] = [
        Note(title: "Ship the modifier-order exercise",
             body: "Split the padding/background example in two and attach a screenshot of each so the difference is unmissable in review.",
             symbol: Category.work.symbol, category: .work),
        Note(title: "Buy the good coffee",
             body: "Not the supermarket own-brand. And oat milk.",
             symbol: Category.errands.symbol, category: .errands),
        Note(title: "Idea: a flow layout for tags",
             body: "Implement Layout.sizeThatFits and placeSubviews so chips wrap onto new lines. Good way to finally understand propose/choose/place end to end.",
             symbol: Category.ideas.symbol, category: .ideas),
        Note(title: "Call the dentist",
             body: "Reschedule the cleaning for after the cohort demo week.",
             symbol: Category.personal.symbol, category: .personal),
        Note(title: "Review the Phase I gate submissions",
             body: "Vapor service, CLI client, shared package — check Swift Testing coverage is above seventy percent on the shared package before signing off.",
             symbol: Category.work.symbol, category: .work),
        Note(title: "Plant the tomatoes",
             body: "The seedlings on the windowsill are ready. Need bigger pots first.",
             symbol: Category.personal.symbol, category: .personal),
    ]
}
```

Notice the variety: a long title, short ones, long and short bodies, four categories. That variety is what stress-tests your layout. If your sample data is six identical "Lorem ipsum" notes, you have not tested anything.

---

## The screen

`ContentView` composes the header and the list. The list is a `ScrollView` + `LazyVStack` (not a `List` — we want full control of the card chrome this week; `List` comes later). It adapts column count by horizontal size class:

```swift
import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let notes = Note.samples

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private var columns: [GridItem] {
        isRegularWidth
            ? [GridItem(.adaptive(minimum: 280), spacing: 16)]
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NoteListHeader(count: notes.count)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(notes) { note in
                        NoteCard(note: note)
                    }
                }
            }
            .frame(maxWidth: isRegularWidth ? 1000 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("iPhone SE · Light") {
    ContentView()
}

#Preview("iPad Pro 13-inch · Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 5") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility5)
}
```

The `NoteListHeader` and `NoteCard` are yours to implement — the challenge's `NoteCard` is a direct fit. The `ForEach(notes)` works without an explicit `id:` precisely because `Note` is `Identifiable`.

---

## Rules

- **You may** read Apple's SwiftUI documentation, the Week 7 lecture notes, your exercises and the challenge, the SF Symbols app, and WWDC session notes.
- **You may NOT** add SwiftData, Core Data, `@State`/`@Observable` mutation, networking, navigation (`NavigationStack`/`NavigationLink`), or any third-party Swift package. This is a static, single-screen, dependency-free app on purpose. (If you find yourself reaching for `@State`, stop — that is next week.)
- **Use a `List`** is *not* required; we use `ScrollView` + `LazyVGrid` for chrome control. You may use `List` for a stretch variant if you keep the default version grid-based.
- **Every colour** must be semantic (`.primary`, `.secondary`, `Color(.systemGroupedBackground)`, etc.) or an asset-catalog colour set with light/dark variants. No literal `Color(red:green:blue:)` that fails in one appearance.
- Target **iOS 18** or newer (the Xcode 16 default). Swift language mode: the project default.
- The build must be **warning-free**. A warning is a defect.

---

## Acceptance criteria

The grading rubric is below; each box maps to a deliverable.

### Correctness & structure (40%)

- [ ] The app builds and runs on the **iPhone SE (3rd generation)** simulator and the **iPad Pro 13-inch (M4)** simulator.
- [ ] At least **six** notes from a hard-coded `[Note]`, with varied title/body lengths and at least three distinct categories.
- [ ] The view hierarchy is decomposed into reusable components (`NoteCard`, `NoteListHeader`, `CategoryBadge`) in separate files — not one 200-line `body`.
- [ ] `Note` is `Identifiable` and the list uses `ForEach(notes)` with stable identity.
- [ ] No `@State`, no mutation, no navigation, no persistence, no third-party packages.

### The matrix (40%)

The recurring Phase II marker:

```
Renders correctly on iPhone SE (3rd gen) and iPad Pro 13-inch,
in light and dark, at Dynamic Type .accessibility5 — no clipping, no truncation.
```

- [ ] **Light & dark** both render correctly with no hand-branching to choose a colour. Toggle with `⌘⇧A` in the simulator and confirm.
- [ ] **Dynamic Type `.accessibility5`**: no clipping, no truncation of titles or badges; cards reflow as needed.
- [ ] **iPhone SE**: single-column list, no horizontal scroll, no clipping.
- [ ] **iPad Pro 13-inch**: uses the extra width sensibly (multi-column grid and/or a capped content width), not a single phone-width column stranded on the left.
- [ ] At least **three `#Preview`** blocks demonstrate the hard combinations (e.g. iPhone light, iPad dark, accessibility5).

### Documentation & polish (20%)

- [ ] A `README.md` at the repo root with: a one-paragraph description, a screenshot strip (iPhone light, iPad dark, accessibility5 — three images), and a short "view hierarchy" section that lists the component tree.
- [ ] A custom **accent colour** set in the asset catalog (not the default blue), reflected in the badges/icons via `.tint`.
- [ ] An **app icon** (any 1024×1024 image is fine this week; a flat colour with an SF Symbol exported is acceptable).
- [ ] A `CardBackground` colour set with distinct light and dark values, used by the cards.
- [ ] Build is **warning-free**.

---

## Suggested implementation outline

The order matters: model first, one card next, then the screen, then harden across the matrix.

### Day 1 (Thursday — ~2 hours)

1. Create the `HelloNotes` project (SwiftUI, storage None). Confirm it runs.
2. Add `Models/Note.swift` with the `Note` struct, `Category` enum, and `Note.samples`. Build.
3. Build `Views/CategoryBadge.swift` and `Views/NoteCard.swift` for the **default** text size only. Get one card looking right in the Canvas.
4. Add `Views/NoteListHeader.swift`. Compose the screen in `ContentView` with the grid. Run on the iPhone SE simulator.

### Day 2 (Friday — ~3 hours)

5. Configure the asset catalog: `AccentColor` (pick a brand colour), `CardBackground` (light + dark), and an app icon. Confirm `.tint` and the card background pick them up.
6. Run on the iPad Pro 13-inch simulator. Fix the layout so it uses the width (adaptive grid, capped content width). Toggle dark mode on both; fix any colour that does not adapt.
7. Add the three `#Preview` blocks. Get the Canvas green on all three.

### Day 3 (Saturday — ~3.5 hours)

8. Crank Dynamic Type to `.accessibility5` (preview environment, then the running simulator via Settings ▸ Accessibility ▸ Display & Text Size ▸ Larger Text). Find every clip and truncation. Make the card reflow (the challenge's approach: a size-class branch or `ViewThatFits`).
9. Re-run the full matrix: iPhone SE + iPad Pro 13-inch × light + dark × default + accessibility5. That is eight checks (six in the marker plus the two default-size device checks). Fix until all pass.
10. Write the repo `README.md`, capture the three screenshots, document the view hierarchy. Commit and push.

---

## What "done" looks like

You open the iPhone SE simulator, the app shows a clean single-column list of six varied note cards. You press `⌘⇧A` — every card flips to dark mode instantly, nothing illegible, no code branch did it. You go to Settings and crank text to the largest accessibility size — the cards grow and reflow, titles wrap, badges drop below the text, nothing clips. You switch the run destination to iPad Pro 13-inch — the cards flow into two or three columns and the content stays a comfortable width instead of stretching to the screen edges. You run all eight combinations and every one reads correctly.

When that is true, you have done Week 7. You have a view hierarchy you can defend modifier by modifier, and you have made "renders on both, in both, at the largest size" an ordinary property of your work — which is exactly the senior reflex this phase is built to install.

---

## Submission

Push the `HelloNotes` project to a GitHub repository (name it `hello-notes` or similar; you will reuse it through Week 12). Confirm a fresh clone opens in Xcode 16, builds warning-free, and runs on both simulators. Include the `README.md` with the three-screenshot strip. In the Week 7 channel, post the repo link and one sentence naming the hardest reflow you had to solve.

## Looking ahead

Week 8 takes this exact app and replaces `Note.samples` with a mutable `@Observable` `NotesStore` injected via `@Environment`, then adds add/edit/delete with an edit sheet — and the list will update *exactly once* per change because you built `body` as a pure function of the data this week. The cleaner your hierarchy is now, the smaller that diff will be. Keep the repo.
