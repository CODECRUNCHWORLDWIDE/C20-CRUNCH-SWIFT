# Week 1 Homework

Six practice problems that revisit the week's topics. The full set should take about **6 hours**. Work in your Week 1 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

A reminder before you start: every `.swift` file in this homework must run clean with `swift <file>.swift` (no warnings, no errors) or, where a package is asked for, `swift build` must print `Build complete!` and `swift test` must report all tests passing. A warning is a bug this week.

---

## Problem 1 — `swift --version` audit

**Problem statement.** Run `swift --version` (and, if you installed via Swiftly, `swiftly list`) on your machine and write the relevant pieces into a file `notes/swift-version.md`. State the value you see for each of the following, and whether it is what you expected:

1. The Swift compiler version (e.g. `Swift version 6.1`).
2. The target triple (e.g. `x86_64-unknown-linux-gnu`, `arm64-apple-macosx14.0`).
3. The platform you are on, and how you installed the toolchain (Swiftly, tarball, Docker image, or Xcode).
4. The output of `swift package --version` (the SwiftPM version that ships with your toolchain).
5. Whether `swift test` finds the **Swift Testing** library out of the box (it should, on a 6.x toolchain).

Then answer in one sentence: *if I run `swift build` on a package with `// swift-tools-version: 6.1`, what language mode does the compiler default to, and what does that mean for concurrency checking?*

**Acceptance criteria.**

- File `notes/swift-version.md` exists with the five values and your one-sentence answer.
- Committed.

**Hint.** `swift --version` prints the compiler version and the target triple. The target triple's last segment is your platform (`linux-gnu`, `apple-macosx`). With `swift-tools-version: 6.1`, the package builds in the **Swift 6 language mode**, which turns on strict concurrency checking by default — that's a Week 4 topic, but the default is set here.

**Estimated time.** 20 minutes.

---

## Problem 2 — Value vs reference, in your own words and in code

**Problem statement.** In a single file `homework/p2-semantics.swift`, define a `struct Counter` and a `class Counter` (name the class `RefCounter` so they can coexist), each with a `var value: Int` and a `mutating`/regular `func bump()`. Write a `main`-level demonstration that:

1. Copies a `Counter` value into a second variable, bumps the copy, and prints both — proving they diverge.
2. Aliases a `RefCounter` into a second variable, bumps the alias, and prints both — proving they stay equal.
3. Prints whether the two `RefCounter` bindings are identical with the `===` operator.

Then, in a comment block at the bottom, write 4–6 sentences explaining *why* the two behave differently and *when you would choose each* in real code.

**Acceptance criteria.**

- `swift homework/p2-semantics.swift` runs clean and prints the four results.
- The `struct` uses a `mutating func`; the `class` uses a regular `func`.
- The comment block answers "why" and "when," not just "what."
- Committed.

**Hint.** A `struct`'s method that changes a property must be marked `mutating`. A `class`'s method changes the instance in place with no keyword. The `===` operator compares *identity* (same instance), distinct from `==` (equal values). Choose `struct` by default (local reasoning, no aliasing surprises); reach for `class` when you need shared mutable identity or reference semantics (e.g. a single live connection).

**Estimated time.** 45 minutes.

---

## Problem 3 — Kill every force-unwrap

**Problem statement.** Below is a deliberately fragile function. Copy it into `homework/p3-safe.swift`, then rewrite it so it contains **zero** force-unwrap `!` operators and never crashes on any input. It should return the average of the integers found in a comma-separated string, ignoring any field that is not an integer, or `nil` if there are no valid integers.

```swift
// BEFORE — crashes on bad input. Do not ship this.
func averageBAD(_ csv: String) -> Double {
    let parts = csv.split(separator: ",")
    let nums = parts.map { Int($0)! }                 // 💥 on a non-number
    return Double(nums.reduce(0, +)) / Double(nums.count)   // 💥 division by zero
}
```

Your `average(_:)` must satisfy:

- `average("1,2,3")` is `2.0`
- `average("1,x,3")` is `2.0` (the `x` is skipped)
- `average("")` is `nil`
- `average("a,b")` is `nil`

Write four `assert`s (or, better, a small Swift Testing target) proving each case.

**Acceptance criteria.**

- `average(_:)` contains zero force-unwrap `!` operators.
- All four cases pass.
- The build is warning-free.
- Committed.

**Hint.** `compactMap { Int($0) }` keeps only the fields that parse, dropping the rest. Then `guard !nums.isEmpty else { return nil }` handles the empty case before you divide. The return type must be `Double?` so the function can honestly say "no answer."

**Estimated time.** 45 minutes.

---

## Problem 4 — A collection pipeline you can read in six months

**Problem statement.** Create `homework/p4-pipeline.swift`. Given a hard-coded `[(name: String, score: Int, subject: String)]` of at least 12 entries across at least three subjects, compute and print:

1. **Average score per subject**, one line per subject in alphabetical order, formatted `cs: 87.50`.
2. **The top 3 scores overall**, printed highest-first as `score — name (subject)`.
3. **The set of names who took more than one subject** (use a `Dictionary(grouping:by:)` on name, then filter).
4. **Distinct subjects**, as a sorted array, derived from a `Set`.

The pipeline must use `Dictionary(grouping:by:)`, `mapValues`, `sorted`, and a `Set` at least once each, and read top-to-bottom with one operator per line where it chains.

**Acceptance criteria.**

- Project builds and runs, printing all four sections.
- `swift homework/p4-pipeline.swift`: no warnings, no errors.
- A `Set` is used for at least part 3 or part 4.
- Committed.

**Hint.** Average per subject: `Dictionary(grouping: records, by: \.subject).mapValues { group in Double(group.map(\.score).reduce(0, +)) / Double(group.count) }`. Top 3: `records.sorted { $0.score > $1.score }.prefix(3)`. Names in multiple subjects: group by name, keep groups whose distinct-subject `Set` has count `> 1`.

**Estimated time.** 1 hour.

---

## Problem 5 — Five parameterized Swift Testing cases

**Problem statement.** Pick a small piece of code you wrote this week — `parsePoint`, `average`, `WordFreq.tokenize`, anything with a clear input/output shape — and write a Swift Testing target that covers it with at least **one parameterized `@Test(arguments:)`** spanning **five or more input rows**, plus at least one `try #require` that unwraps an optional safely.

**Acceptance criteria.**

- A SwiftPM package (or a test target added to an existing one) with a Swift Testing suite.
- At least one `@Test(arguments:)` with five or more rows.
- At least one `try #require(...)` used to unwrap an optional (zero force-unwraps in the test code).
- `swift test` reports all of them passing.
- Committed.

**Hint.**

```swift
import Testing
@testable import WordFreqCore

@Test(arguments: [
    ("hello world", 2),
    ("", 0),
    ("a a a", 3),
    ("Don't, stop!", 3),     // don, t, stop
    ("123 abc", 2),
])
func tokenizeCounts(input: String, expected: Int) {
    #expect(WordFreq.tokenize(input).count == expected)
}

@Test func requireUnwrapsCleanly() throws {
    let n = try #require(Int("42"))
    #expect(n == 42)
}
```

**Estimated time.** 1 hour.

---

## Problem 6 — Mini reflection essay

**Problem statement.** Write a 300–400 word reflection at `notes/week-01-reflection.md` answering:

1. Which felt easiest this week: the toolchain and SwiftPM, value-vs-reference semantics, or optionals? Which felt hardest? Why?
2. Did anything you previously believed about Swift (or about Apple-only languages) turn out to be wrong this week? If so, what?
3. If you had to explain "Swift has no `null`" to a colleague who writes Java or TypeScript in one paragraph, what would you say?
4. What's one thing you want to learn next that this week didn't cover?

**Acceptance criteria.**

- File exists, 300–400 words.
- Each numbered question is addressed in its own paragraph.
- File is committed.

**Hint.** This is for *you*, not for a grade. Be honest. Future-you reading it after Week 6 will be grateful — especially the paragraph on optionals, which is the habit that takes the longest to settle.

**Estimated time.** 30 minutes.

---

## Time budget recap

| Problem | Estimated time |
|--------:|--------------:|
| 1 | 20 min |
| 2 | 45 min |
| 3 | 45 min |
| 4 | 1 h 0 min |
| 5 | 1 h 0 min |
| 6 | 30 min |
| **Total** | **~4 h 20 min** |

When you've finished all six, push your repo and open the [mini-project](./07-mini-project/00-overview.md).
