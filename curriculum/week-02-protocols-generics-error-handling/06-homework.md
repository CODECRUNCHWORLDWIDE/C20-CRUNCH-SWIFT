# Week 2 Homework

Six practice problems that revisit the week's topics — protocol-oriented programming, generics and `associatedtype`, `some` vs `any`, type erasure, and the Swift error model. The full set should take about **6 hours** in total. Work in your Week 2 Git repository (a SwiftPM package is the easiest container) so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets the **Swift 6 toolchain** in **language mode 6**, on Linux, macOS, or Windows + WSL2 — no Mac or Xcode required. Every problem must build with **warnings treated as errors**: `swift build -Xswiftc -warnings-as-errors`. A warning is a bug this week, exactly as it was in Week 1. Where a problem ships tests, `swift test` must print **0 failures**.

---

## Problem 1 — A protocol extension and the dispatch gotcha

**Problem statement.** Define a protocol `Describable` with a single requirement `var summary: String { get }` and a protocol extension that adds a *non-requirement* method `var shout: String { get } // summary.uppercased() + "!"`. Conform two types: a `struct Invoice` that implements `summary`, and a `struct Receipt` that implements `summary` **and** redeclares `shout` with its own body. Then write a function `func announce(_ items: [any Describable])` that prints each item's `shout`, and a second loop that prints `(item as Receipt).shout` for the receipts. Observe and document, in a `notes/dispatch.md`, why the array-of-`any` loop calls the *extension's* `shout` for a `Receipt` even though `Receipt` redeclared it — and what one change to `Describable` would make it call `Receipt`'s version instead.

**Acceptance criteria.**

- `Describable` with `summary` as a requirement and `shout` defined *only* in the extension (not listed as a protocol requirement).
- `Invoice` and `Receipt` conform; `Receipt` redeclares `shout`.
- `announce([any Describable])` demonstrates the static-dispatch surprise: `Receipt` printed through the `any Describable` array uses the extension's `shout`, not `Receipt`'s.
- `notes/dispatch.md` explains why (extension-only methods are statically dispatched on the *static* type, which is `any Describable`) and names the fix (add `var shout: String { get }` to the protocol so it becomes a dynamically dispatched requirement).
- Builds with `-warnings-as-errors`. Committed.

**Hint.** This is the gotcha from Lecture 1, §"the static-vs-dynamic dispatch gotcha". A method that lives *only* in a protocol extension is dispatched on the type the compiler sees at the call site. Through `any Describable` the compiler sees `Describable`, so it picks the extension body. Promote `shout` to a protocol requirement and the witness table routes the call to `Receipt`'s override. Prove it both ways before you write the note.

**Estimated time.** 45 minutes.

---

## Problem 2 — A generic `Stack<Element>` with conditional conformance

**Problem statement.** Implement a value-type `struct Stack<Element>` with `push`, `pop` (returns `Element?`), `peek`, `isEmpty`, and `count`. Make it conform to `Sequence` (top-of-stack first) by giving it an `IteratorProtocol`-backed iterator. Then add **conditional conformance**: `extension Stack: Equatable where Element: Equatable` and `extension Stack: CustomStringConvertible where Element: CustomStringConvertible`. Write Swift Testing cases proving the LIFO order, the `Sequence` conformance (so `map`, `filter`, `reduce`, `contains` all work for free), and that two stacks of `Int` compare equal element-by-element.

**Acceptance criteria.**

- `Stack<Element>` is a `struct` (value semantics) with the five operations.
- `Sequence` conformance via a custom iterator; iterating yields elements top-first.
- Conditional `Equatable` and `CustomStringConvertible` conformances, each gated on `where Element: …`.
- At least 6 passing tests, including one that uses an inherited `Sequence` method (`reduce`/`filter`/`contains`) and one that asserts `Stack([1,2,3]) == Stack([1,2,3])`.
- Builds with `-warnings-as-errors`; `swift test` shows 0 failures. Committed.

**Hint.** For `Sequence`, the simplest iterator copies the backing array and pops in `next()` — or iterate the storage in reverse. Conditional conformance is the `where Element: Equatable` clause from Lecture 1; the compiler synthesises `==` for you if every stored property is `Equatable`, so the extension body can be empty. Do **not** make `Stack` a `class`; the point is value semantics, and a copied stack must not share storage with its source.

**Estimated time.** 55 minutes.

---

## Problem 3 — `some` vs `any` vs a named generic, with a decision log

**Problem statement.** You are given three function signatures to write, each returning or accepting a `Shape` (a protocol with `func area() -> Double`). Implement all three and write a `notes/some-any.md` that states, for each, whether you used `some`, `any`, or a named generic `<T: Shape>`, and the one-line reason:

1. `makeUnitSquare() -> ???` — a factory that always returns the *same concrete* shape type.
2. `totalArea(of shapes: ???) -> Double` — sums the area of a heterogeneous list (squares, circles, triangles mixed).
3. `scaled<???>(_ shape: ???, by factor: Double) -> ???` — returns a shape of the *same concrete type* as the input, scaled.

For (3), the return type's concrete identity must be preserved (a scaled `Circle` is a `Circle`, statically), which a bare `any` would erase.

**Acceptance criteria.**

- (1) returns `some Shape` (opaque — one hidden concrete type, no existential box).
- (2) accepts `[any Shape]` (existential — genuine run-time heterogeneity is required).
- (3) is generic `<S: Shape>(_ shape: S, by: Double) -> S` — the concrete type flows in and out.
- `notes/some-any.md` justifies each choice against the Lecture 2 decision matrix, and names the run-time cost avoided by *not* using `any` in (1) and (3) (no existential boxing / dynamic dispatch).
- Builds with `-warnings-as-errors`. Committed.

**Hint.** The matrix from Lecture 2: reach for `any` only when you genuinely need to store or pass a *mix* of concrete types in one collection or variable — that is (2). When there is exactly one concrete type that the caller should not have to name, that is `some` — (1). When the concrete type must round-trip in and out so the caller keeps it, that is a named generic — (3). If you find yourself writing `any` in (1) or (3), you are paying for boxing you do not need.

**Estimated time.** 50 minutes.

---

## Problem 4 — Hand-build a type eraser

**Problem statement.** Start from a protocol with an associated type — `protocol Producer { associatedtype Output; func produce() -> Output }` — which therefore *cannot* be used as a bare type (`[any Producer]` of mixed `Output`s won't let you call `produce()` usefully without erasure). Hand-write the classic **three-layer type eraser** `AnyProducer<Output>`: an abstract box base class, a concrete box subclass that wraps a real `Producer`, and the public `AnyProducer` struct that forwards through the box. Prove that you can now hold `[AnyProducer<Int>]` containing two *different* concrete producers and call `produce()` on each. Then write one sentence in `notes/erasure.md` on when Swift's **constrained existential** (`any Producer<Int>`) makes the hand-built eraser unnecessary.

**Acceptance criteria.**

- A PAT `Producer` with `associatedtype Output`.
- Two distinct concrete conformers (e.g. `ConstantProducer`, `CountingProducer`).
- `AnyProducer<Output>` built as three layers: `private class _AnyProducerBase<Output>`, `private final class _ProducerBox<P: Producer>`, and the public erasing wrapper.
- A test or `main` that stores both concrete producers in `[AnyProducer<Int>]` and calls `produce()` on each, asserting the expected values.
- `notes/erasure.md`: one sentence noting that since SE-0309 + primary associated types, `any Producer<Int>` often replaces a hand-written eraser, but a hand eraser is still needed to add stored state or to support older language features.
- Builds with `-warnings-as-errors`. Committed.

**Hint.** The base box exposes `func produce() -> Output` as a method that `fatalError`s (it is never called directly); the concrete box stores the real producer and overrides `produce()` to forward. `AnyProducer`'s `init<P: Producer>(_ p: P) where P.Output == Output` constructs a `_ProducerBox(p)` and stores it as the base type. This is exactly `AnySequence`'s shape — the standard library does the same thing you are doing by hand. (Lecture 2, type-erasure section.)

**Estimated time.** 60 minutes.

---

## Problem 5 — Model an error domain with typed throws and `Result`

**Problem statement.** Model a small domain: a `func parseTemperature(_ raw: String) throws(ParseError) -> Double` that accepts strings like `"21.5C"` or `"70F"` and returns degrees Celsius, throwing a **typed** error `enum ParseError: Error, Equatable` with cases `empty`, `missingUnit`, `unknownUnit(Character)`, and `notANumber(String)`. Then write three call sites exercising the full `try` family against it: a `do`/`catch` that switches exhaustively on `ParseError`, a `try?` site that supplies a default, and a `result(_:) -> Result<Double, ParseError>` wrapper. Add a `mapError`/`map` transformation on the `Result`. Write Swift Testing cases asserting each error case fires for the right input and that valid inputs convert correctly (`"212F"` → `100.0`).

**Acceptance criteria.**

- `parseTemperature` uses **typed throws** — `throws(ParseError)`, not untyped `throws`.
- `ParseError` is `Equatable` so tests can assert the exact case (`#expect(throws: ParseError.unknownUnit("K"))`).
- Three call sites: exhaustive `do`/`catch` (no `default:` needed because the error type is known), a `try?` with a fallback, and a `Result`-returning wrapper.
- At least one `Result` transformation (`map` the Celsius value, or `mapError` into a higher-level error).
- Tests cover every `ParseError` case plus two valid conversions (one C, one F). `swift test` shows 0 failures. Builds with `-warnings-as-errors`. Committed.

**Hint.** Typed throws (Lecture 2) is what lets the `catch` be exhaustive without a `default:` — the compiler knows only `ParseError` can be thrown, so `case .empty`, `.missingUnit`, `.unknownUnit`, `.notANumber` covers it. For the F→C conversion use `(f - 32) * 5 / 9`. `Result { try parseTemperature(raw) }` only infers `Result<Double, any Error>`; to keep the typed `Result<Double, ParseError>` you write the `do`/`catch` and build the `.success`/`.failure` by hand, or use the typed-throws-aware initializer. Do **not** reach for `try!` — there is no input you control well enough to justify it here.

**Estimated time.** 55 minutes.

---

## Problem 6 — A generic `Validated` pipeline with `defer` cleanup

**Problem statement.** Write a generic function `func withTempFile<T>(_ body: (URL) throws -> T) throws -> T` that creates a unique temp file, guarantees it is deleted with a `defer` **even when `body` throws**, and returns whatever `body` returns. Then build a tiny generic validation pipeline: a `protocol Rule { associatedtype Value; func check(_ value: Value) throws -> Value }`, two concrete rules (`NonEmpty` for `String`, `InRange` for `Int`), and a generic `func validate<R: Rule>(_ value: R.Value, with rule: R) throws -> R.Value`. Prove with tests that (a) `withTempFile` deletes the file on both the success and the throwing path, and (b) a failing rule throws and a passing rule returns the value unchanged.

**Acceptance criteria.**

- `withTempFile` uses `defer { try? FileManager.default.removeItem(at: url) }` so cleanup runs whether `body` returns or throws.
- A test proves the temp file no longer exists after `withTempFile` returns **and** after it throws (run it both ways and assert `FileManager.default.fileExists` is `false`).
- `Rule` is a PAT; `NonEmpty` (rejects `""` with a thrown error) and `InRange` conform; `validate(_:with:)` is generic over `R: Rule` and pins `R.Value`.
- Tests: a failing `NonEmpty` throws, a passing one returns the input; `InRange` likewise. `swift test` shows 0 failures. Builds with `-warnings-as-errors`. Committed.

**Hint.** `defer` runs on *every* exit from the scope, including a thrown error propagating out — that is exactly why it is the right tool for resource cleanup (Lecture 2). To prove the throwing-path cleanup, pass a `body` that throws after the file exists, catch the error in the test, then assert the file is gone. For the rules, `validate` is a one-liner — `try rule.check(value)` — but writing it generic over `R: Rule` with `R.Value` is the associated-type-constraint skill from Lecture 1 doing real work.

**Estimated time.** 55 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with `-warnings-as-errors`, `swift test` is green where tests are required, code is idiomatic protocol-oriented Swift, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a `class` where a `struct` was the point, an untyped `throws` where typed was asked, a gratuitous `any`). |
| 3 | Works, but misses one criterion (e.g. the dispatch note explains the symptom but not the fix; the eraser compiles but only holds one concrete type; `Result` transformation omitted). |
| 2 | Compiles and partially works; a core idea is wrong (the eraser is two layers and leaks the concrete type; `some` used where `any` was required, breaking heterogeneity; `try!` used on a recoverable path). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any `try!` or force-unwrap on an optional you did not just create in the same scope; **−2** for any warning left in the build (we compile with `-warnings-as-errors` for a reason); **−1** for reaching for `any` where `some` or a named generic was correct (a paid-for existential box you didn't need).

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the `some`/`any`/generic decision (problems 3, 4) and the error model with typed throws and `Result` (problems 5, 6) — so re-run exercises 02 and 03 before resubmitting.
