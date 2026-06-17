# Challenge 1 — The same feature, three ways (with numbers and an ADR)

**Time.** 90–150 minutes.
**Deliverable.** Three implementations of one feature in a `ThreeWays` repo, an `ARCHITECTURE.md` with the measurements, and an `ADR.md` that picks a winner for two different contexts. Committed.

## The premise

Every senior engineer eventually has the "what architecture should we use?" conversation, and the weak answer is a preference ("I like TCA" / "MVVM is simpler"). The strong answer is a *measured trade for a specific context*. The skill this challenge builds is exactly that: implement the **same** feature three ways, put numbers on what each costs, then write the ADR that picks one — and a *different* one — for two different contexts. A choice you can't quantify and contextualise is a preference, not an engineering decision.

You will build one small feature three times, measure three things about each, then decide.

## The feature (identical across all three)

A **searchable, loadable list of "products"**:

- On appear, load products from a repository (an `async` call that can fail).
- A search field filters the list by name (case-insensitive substring).
- Show a loading spinner while loading and an error message if the load fails.
- A "favorite" toggle on each row that flips an in-memory `isFavorite` flag.

Keep the domain trivial so the *architecture* is the variable, not the business logic:

```swift
struct Product: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    var isFavorite: Bool = false
}

// The dependency seam — identical for all three implementations.
struct ProductRepository: Sendable {
    var load: @Sendable () async throws -> [Product]

    static let live = ProductRepository(load: {
        // Pretend network: a fixed list after a tiny delay.
        try await Task.sleep(for: .milliseconds(50))
        return (1...30).map { Product(id: $0, name: "Product \($0)") }
    })
    static func stub(_ products: [Product], error: Error? = nil) -> ProductRepository {
        ProductRepository(load: {
            if let error { throw error }
            return products
        })
    }
}
```

### Implementation A — plain SwiftUI + `@Observable`

Logic in (or one `@State` away from) the view; no separate "view model" concept, no test target. This is the far-left of the axis. It is allowed to use an `@Observable` holder, but you do **not** write tests for it (that is the point — measure how much the lack of structure costs you in testability).

### Implementation B — MVVM

An `@Observable @MainActor ProductListModel` that takes the `ProductRepository` through `init`, owns `products`/`query`/`isLoading`/`loadError`, exposes `visibleProducts` as derived state, and has `load()` and `toggleFavorite(_:)` intent methods. A dumb view. A **Swift Testing suite** that injects a stub repository and asserts: load populates, load surfaces errors, filtering works, favoriting flips the flag.

### Implementation C — TCA

A `@Reducer ProductListFeature` with `@ObservableState` value-type `State`, an `Action` enum (`.onAppear`, `.binding(\.query)`, `.productsResponse`, `.favoriteTapped(id:)`), a `@Dependency(\.productRepository)`, and the matching `Effect`s. A **`TestStore` suite** that proves the same four behaviours exhaustively, with the repository overridden in `withDependencies`.

## What to measure

Record all of this in `ARCHITECTURE.md`. The measuring *is* the challenge.

### 1. Line count

Count the production lines (not tests, not comments, not blank lines) for each implementation. Use a tool, don't eyeball:

```bash
# from each implementation's directory:
find . -name '*.swift' -not -path '*Tests*' \
  | xargs grep -vE '^\s*(//|$)' | wc -l
```

You will find roughly: A < B < C, often by a meaningful multiple. That multiple is the *boilerplate cost* of structure, and naming it is the point.

### 2. Test coverage of the logic

For B and C, what fraction of the *behaviour* can you assert without a UI? (A has effectively none.) Note specifically: in C, the `TestStore` forces you to assert *every* state change and receive *every* effect — so coverage is exhaustive by construction. In B, coverage is whatever you remembered to write. Note which behaviours you'd *forget* to test in B that C *makes* you test.

### 3. The cost of one realistic change

Pick one change and implement it in all three: **"add a `category` filter alongside the search query — products must match both."** Time yourself (roughly) and count the lines touched in each implementation. Note where the change is *localised* (one place) versus *scattered* (state + action + reducer + view). Structure usually makes a change more *traceable* (you know exactly the four places to touch in TCA) but more *verbose* (you touch four places). Capture that tension.

## The ADR (the real deliverable)

Write `ADR.md` using the five-section format from lecture 2, §6. But here is the twist that makes it a *senior* artifact: write the decision for **two different contexts** and explain why the answer differs.

- **Context 1 — a throwaway prototype** you are building this week to validate an idea with three users, then almost certainly deleting. Which implementation ships? (Hint: run the three questions — testability need, team size, longevity. All low.)
- **Context 2 — a six-engineer team building a feature that touches money/orders, maintained for three years.** Which implementation ships? (Run the same three questions. Different answers.)

The ADR must explicitly: state both decisions, reference the *measurements* you took (not vibes — "TCA was 2.4× the lines but the only one with exhaustive coverage"), name the rejected options for each context, and state the consequences. If both contexts pick the same architecture, you have probably not internalised the axis — go re-run the three questions honestly.

## Acceptance criteria

- [ ] All three implementations build, run in the Simulator, and behave identically (load, search, error, favorite).
- [ ] B has a Swift Testing suite; C has a `TestStore` suite; both prove the four core behaviours. A has no tests (deliberately).
- [ ] `ARCHITECTURE.md` records: the three line counts (with the command used), a note on test coverage per implementation, and the change-cost measurement for the `category` filter across all three.
- [ ] `ADR.md` decides for **both** contexts (throwaway prototype; six-engineer money-touching app), references the measurements, names rejected options, and states consequences — and the two decisions **differ**, with the difference explained via the three questions.
- [ ] Everything builds with **0 warnings**, including Swift 6 strict concurrency.

## What "great" looks like

A weak submission says "TCA is more testable but more code; I'd use MVVM." A great submission says:

> Plain SwiftUI was 41 production lines with zero testable logic. MVVM was 78 lines (1.9×) with a 6-test suite covering load/error/filter/favorite. TCA was 121 lines (3.0×) with a `TestStore` suite that *forced* coverage of every state transition and both effects — it caught that I'd forgotten to clear `loadError` on a retry, which my MVVM tests didn't assert because I didn't think to. The `category` filter change touched 1 site in plain SwiftUI, 2 in MVVM (model + view), and 4 in TCA (State, Action, reducer, view) — but the TCA change was the only one where I could *prove* the new filter didn't regress the old behaviour. For the throwaway prototype I ship **plain SwiftUI**: testability need, team size, and longevity are all low, so structure is pure cost. For the six-engineer money-touching app I ship **TCA**: a wrong order-state transition is expensive, the team needs one legible shape, and the feature lives for years — the 3× line cost buys exhaustive proof, which is the cheapest insurance against a money bug.

Quantified, contextual, honest about what each architecture did and didn't catch. That's the senior answer — and it is the answer to "what architecture do you like?" that actually lands in an interview.

## Where this reappears

The judgment you built here — match structure to stakes, measure the trade, write the ADR — is the spine of every architecture conversation in the rest of the track. The Phase II integration project (Week 12) asks you to pick an architecture for "Notes v1" and defend it; the capstone (Phase IV) requires an architecture diagram and decision records as graded deliverables. The "I can defend it with numbers and an ADR" muscle is the one being built here.
