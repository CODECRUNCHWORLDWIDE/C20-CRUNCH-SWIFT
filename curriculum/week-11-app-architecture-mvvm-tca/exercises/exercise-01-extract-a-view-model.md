# Exercise 1 — Extract a testable view model

**Goal.** Take a SwiftUI view that has business logic and a hidden dependency crammed inside it, and refactor it into the MVVM discipline: an `@Observable` `@MainActor` view model that owns the state and logic, a dumb view that only renders and forwards intent, and an *injected* dependency that gives you a test seam. Then write a Swift Testing suite that exercises the logic with zero UI. This is lecture 1, §3 and §5 made concrete — if you can do this, you understand what MVVM buys.

**Estimated time.** 45 minutes.

**Prerequisites.** Xcode 16+, an iOS 18 Simulator (iOS 17 works). No Swift Package needed — this is plain SwiftUI + `@Observable`. The Hello, Notes app is not required; we use a self-contained `TipCalculator` so the focus stays on the refactor.

---

## Step 1 — Start from the smell

Here is the view you are going to fix. It works, and it is a mess: business logic in `body`, a hidden dependency on the live `Date`, and nothing you can test without a SwiftUI runtime.

```swift
import SwiftUI

struct TipScreen: View {
    @State private var billText = ""
    @State private var tipPercent = 18.0
    @State private var partySize = 1

    var body: some View {
        Form {
            TextField("Bill amount", text: $billText)
                .keyboardType(.decimalPad)
            Slider(value: $tipPercent, in: 0...30, step: 1) {
                Text("Tip")
            }
            Stepper("Party of \(partySize)", value: $partySize, in: 1...20)

            // ☠️ business logic living in the view
            let bill = Double(billText) ?? 0
            let tip = bill * tipPercent / 100
            let total = bill + tip
            let perPerson = total / Double(partySize)

            LabeledContent("Tip", value: tip, format: .currency(code: "USD"))
            LabeledContent("Total", value: total, format: .currency(code: "USD"))
            LabeledContent("Per person", value: perPerson, format: .currency(code: "USD"))

            // ☠️ a hidden dependency: the live clock, reached for directly
            Text("Calculated at \(Date.now.formatted(date: .omitted, time: .standard))")
                .font(.caption)
        }
    }
}
```

Run it. It works. Now make it testable.

## Step 2 — Define the dependency seam

The hidden dependency here is `Date.now`. To test "the timestamp is recorded," you need to control time. Make a clock abstraction — the smallest possible struct-of-closures (lecture 1, §5):

```swift
import Foundation

struct DateProvider: Sendable {
    var now: @Sendable () -> Date

    static let live = DateProvider(now: { Date() })
    static func fixed(_ date: Date) -> DateProvider {
        DateProvider(now: { date })
    }
}
```

`DateProvider.live` returns the real clock; `DateProvider.fixed(_:)` returns whatever you pass — that is your test seam.

## Step 3 — Write the view model

Pull every piece of logic and state out of the view and into an `@Observable` `@MainActor` class. The dependency comes in through `init`.

```swift
import Foundation
import Observation

@Observable
@MainActor
final class TipCalculatorModel {
    // MARK: Inputs the view binds to
    var billText = ""
    var tipPercent = 18.0
    var partySize = 1

    // MARK: Injected dependency
    private let dateProvider: DateProvider
    private(set) var calculatedAt: Date

    init(dateProvider: DateProvider = .live) {
        self.dateProvider = dateProvider
        self.calculatedAt = dateProvider.now()
    }

    // MARK: Derived state — pure, trivially testable
    var bill: Double { Double(billText) ?? 0 }
    var tip: Double { bill * tipPercent / 100 }
    var total: Double { bill + tip }
    var perPerson: Double {
        guard partySize > 0 else { return 0 }
        return total / Double(partySize)
    }

    // MARK: Intent
    func recalculate() {
        // touching the inputs already updates the derived values; this records
        // the time the user asked for a fresh calculation.
        calculatedAt = dateProvider.now()
    }
}
```

Decisions to be able to defend in review:

- **`@MainActor`** — this is UI-facing state read on the main thread; the macro makes that explicit and the compiler enforces it (lecture 1, §3).
- **Derived values are computed properties**, not stored — they recompute from the inputs, so there is no stale-state bug class. `bill`, `tip`, `total`, `perPerson` are pure functions of the inputs.
- **`guard partySize > 0`** — the original view would divide by zero if `partySize` were ever 0. Pulling logic into the model is where you *notice* and fix edge cases like this. That noticing is half the value of the extraction.
- **`dateProvider: DateProvider = .live`** — the default is the live clock, so production code reads naturally; tests pass `.fixed(...)`.

## Step 4 — Make the view dumb

The view now holds the model via `@State` and does nothing but render and bind:

```swift
import SwiftUI

struct TipScreen: View {
    @State private var model = TipCalculatorModel()

    var body: some View {
        Form {
            TextField("Bill amount", text: $model.billText)
                .keyboardType(.decimalPad)
            Slider(value: $model.tipPercent, in: 0...30, step: 1) { Text("Tip") }
            Stepper("Party of \(model.partySize)", value: $model.partySize, in: 1...20)

            LabeledContent("Tip", value: model.tip, format: .currency(code: "USD"))
            LabeledContent("Total", value: model.total, format: .currency(code: "USD"))
            LabeledContent("Per person", value: model.perPerson, format: .currency(code: "USD"))

            Text("Calculated at \(model.calculatedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption)

            Button("Recalculate", action: model.recalculate)
        }
    }
}

#Preview {
    TipScreen()
}
```

Count the business-logic lines in `body`: zero. Every number comes from the model; every input binds to the model; the only "logic" left is formatting, which is presentation.

## Step 5 — Test the logic with zero UI

This is the payoff. Drop this into a test target and run Cmd-U.

```swift
import Testing
import Foundation
@testable import YourAppModule   // replace with your target name

@MainActor
struct TipCalculatorModelTests {
    @Test("tip, total, and per-person compute correctly")
    func arithmetic() {
        let model = TipCalculatorModel(dateProvider: .fixed(.distantPast))
        model.billText = "100"
        model.tipPercent = 20
        model.partySize = 4

        #expect(model.tip == 20)
        #expect(model.total == 120)
        #expect(model.perPerson == 30)
    }

    @Test("a non-numeric bill is treated as zero, not a crash")
    func garbageBill() {
        let model = TipCalculatorModel(dateProvider: .fixed(.distantPast))
        model.billText = "not a number"
        #expect(model.bill == 0)
        #expect(model.total == 0)
    }

    @Test("party of zero does not divide by zero")
    func zeroParty() {
        let model = TipCalculatorModel(dateProvider: .fixed(.distantPast))
        model.billText = "50"
        model.partySize = 0
        #expect(model.perPerson == 0)   // the guard, proven
    }

    @Test("recalculate records the injected time, not the wall clock")
    func injectedTime() {
        let fixed = Date(timeIntervalSince1970: 1_000_000)
        let model = TipCalculatorModel(dateProvider: .fixed(fixed))

        model.recalculate()

        #expect(model.calculatedAt == fixed)   // deterministic because time was injected
    }
}
```

Run it. Four fast, deterministic tests, no Simulator UI, no flake. The `injectedTime` test is the one that *could not have been written* against the original view — there was no seam to control `Date.now`. The injection created the seam; the seam created the test.

---

## Acceptance criteria

- [ ] A `DateProvider` struct-of-closures with `.live` and `.fixed(_:)`.
- [ ] A `TipCalculatorModel` that is `@Observable`, `@MainActor`, owns all inputs and derived values, and takes `DateProvider` through `init`.
- [ ] A `TipScreen` view with **zero business logic** in `body` — every value comes from the model.
- [ ] The division-by-zero edge case is handled in the model (and proven by a test).
- [ ] A Swift Testing suite with at least four tests, including one that asserts the *injected* time — provably impossible without the seam.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict concurrency.

## What you just proved

You converted an untestable view into a testable feature by applying exactly the two rules from lecture 1: **the logic lives in an `@Observable` view model** (so it is instantiable and assertable), and **the dependency is injected, not reached for** (so a test can control it). The `injectedTime` test is the whole thesis of MVVM in one assertion — structure bought you a test you could not otherwise write. You also found and fixed a divide-by-zero you would never have noticed with the logic buried in `body`. That noticing is the quiet bonus of pulling logic out of the view.

---

## Hints (read only if stuck > 10 min)

- **`@testable import` fails to find your module.** The module name is your *target* name (Xcode ▸ target ▸ General ▸ "Bundle Identifier" is not it — it is the target's name, e.g. `Scratch`). Match it exactly.
- **`@State private var model = TipCalculatorModel()` warns about main-actor isolation.** The default `init` is `@MainActor`-isolated because the class is; initialising it in a `@State` default inside a SwiftUI `View` (also main-actor) is fine. If you see a warning, ensure the view is not marked `nonisolated`.
- **A test fails on `model.tip == 20` by a hair.** Floating-point. `100 * 20 / 100` is exactly `20` here, but if you tweak inputs you may need `#expect(abs(model.tip - 20) < 0.0001)`. For the given inputs the values are exact.
- **The model resets between renders in the Simulator.** You used `let model = ...` instead of `@State private var model = ...`. `@State` keeps the same instance alive across re-renders (lecture 1, §3); a `let` makes a fresh one each time `body` runs.
