# Week 1 — Quiz

Twelve multiple-choice questions. Take it with your lecture notes closed. Aim for 9/12 before moving to Week 2. Answer key at the bottom — don't peek.

---

**Q1.** Which statement about the Swift language and the Apple platforms is correct in 2026?

- A) Swift only runs on Apple platforms; you need a Mac and Xcode to compile any Swift program.
- B) Swift is open-source (Apache-2.0), and its compiler, standard library, SwiftPM, and Swift Testing run on Linux, macOS, and Windows.
- C) Swift on Linux is a community fork with a different syntax from Apple's Swift.
- D) Swift requires the .NET runtime to execute on non-Apple platforms.

---

**Q2.** Given:

```swift
struct Point { var x: Int; var y: Int }
var a = Point(x: 1, y: 2)
var b = a
b.x = 99
print(a.x, b.x)
```

What does this print?

- A) `99 99` — `b` is a reference to the same `Point` as `a`.
- B) `1 99` — `struct` is a value type, so `b = a` copies; mutating `b` does not touch `a`.
- C) `1 1` — assigning a `struct` to a `var` makes both immutable.
- D) It does not compile — you cannot mutate a `struct`'s property.

---

**Q3.** Replace `struct` with `class` in Q2:

```swift
class Point { var x: Int; var y: Int; init(x: Int, y: Int) { self.x = x; self.y = y } }
let a = Point(x: 1, y: 2)
let b = a
b.x = 99
print(a.x, b.x)
```

What does this print?

- A) `1 99` — classes copy on assignment.
- B) `99 99` — `class` is a reference type; `a` and `b` point to the same instance, and `let` only forbids reassigning the *binding*, not mutating the instance's `var` properties.
- C) It does not compile — you cannot mutate through a `let` binding.
- D) `1 1` — `let` makes the instance fully immutable.

---

**Q4.** What is the type of `value` after this line?

```swift
let value = Int("42")
```

- A) `Int` — the string parses successfully.
- B) `Int?` (`Optional<Int>`) — the failable initializer `Int(_:)` returns `nil` on input it cannot parse.
- C) `String` — it just stores the original text.
- D) It does not compile without a type annotation.

---

**Q5.** Which expression idiomatically returns `"guest"` when `name` (of type `String?`) is `nil`?

- A) `name == nil ? "guest" : name`
- B) `name ?? "guest"`
- C) `name!`
- D) `name?.description ?? name`

---

**Q6.** You have `let maybeName: String? = fetchName()`. Which is the **best** way to use it only when it has a value, keeping the rest of the function un-indented?

- A) `if let name = maybeName { /* long body */ }`
- B) `let name = maybeName!`
- C) `guard let name = maybeName else { return }` — then use `name` below.
- D) `let name = maybeName ?? maybeName!`

(Choose the best answer for an *early-exit* style, not just one that compiles.)

---

**Q7.** What does this print?

```swift
let parts = "a,,b".split(separator: ",")
print(parts.count)
```

- A) `3` — empty fields are kept.
- B) `2` — `split(separator:)` omits empty subsequences by default.
- C) `1` — the whole string is one element.
- D) It crashes on the empty middle field.

---

**Q8.** Which statement about Swift `Dictionary` iteration order is true?

- A) A `Dictionary` always iterates in insertion order.
- B) A `Dictionary` always iterates in sorted-key order.
- C) A `Dictionary` has no guaranteed iteration order; to get a stable order you must `sorted(...)` it.
- D) Iteration order is alphabetical on macOS and insertion-order on Linux.

---

**Q9.** What does this expression evaluate to?

```swift
func describe(_ xs: [Int]) -> String {
    switch xs {
    case []:            return "empty"
    case [let only]:    return "one: \(only)"
    case [_, _]:        return "two"
    default:            return "many"
    }
}
describe([10, 20, 30])
```

- A) `"empty"`
- B) `"one: 10"`
- C) `"two"`
- D) `"many"`

---

**Q10.** You write `let x = someOptional!` and the value happens to be `nil` at runtime. What happens?

- A) `x` is assigned `nil` and the program continues.
- B) The program traps (crashes) with a fatal error — force-unwrapping `nil` is a runtime trap, exactly the bug class optionals exist to prevent.
- C) A compile error — `!` is never allowed.
- D) `x` is assigned a default zero value.

---

**Q11.** Which `Package.swift` target kind produces a runnable command-line program, and which produces a `.swiftmodule` consumed by other targets?

- A) `.executableTarget` is runnable; `.target` (a regular library target) is consumed by others.
- B) `.libraryTarget` is runnable; `.mainTarget` is consumed by others.
- C) Both `.target` and `.executableTarget` are runnable; there is no library target.
- D) `Package.swift` does not declare targets; SwiftPM infers everything.

---

**Q12.** In Swift Testing, what is the difference between `#expect` and `#require`?

- A) They are identical; `#require` is a deprecated alias.
- B) `#expect` records a failure and continues the test; `#require` records a failure and stops the test (it `throws`), which is why it is used to unwrap optionals safely.
- C) `#expect` is for unit tests; `#require` is for UI tests only.
- D) `#require` runs only on macOS; `#expect` runs on Linux.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — Swift is open-source under Apache-2.0, developed at `github.com/swiftlang/swift`. The compiler, standard library, SwiftPM, the REPL, and Swift Testing all run on Linux, macOS, and Windows. Phase I of this course never touches a Mac.
2. **B** — `struct` is a value type. `var b = a` copies the value; mutating `b.x` leaves `a` untouched. This is *the* defining behavior of value types and the thing that surprises engineers arriving from reference-default languages.
3. **B** — `class` is a reference type. `a` and `b` are two bindings to the *same* instance, so writing through `b` is visible through `a`. `let` only prevents reassigning the binding (`b = somethingElse`); it does not freeze the instance's `var` properties. This is the contrast that makes Q2/Q3 the most important pair in the week.
4. **B** — `Int(_:)` is a *failable initializer*: it returns `Int?`. `Int("42")` is `Optional(42)`; `Int("forty")` is `nil`. The compiler infers `Int?`, and you must unwrap before using it as an `Int`.
5. **B** — `??` is the nil-coalescing operator: "the wrapped value, or this default if `nil`." A works but is verbose and re-evaluates `name`. C crashes when `name` is `nil`. D is nonsense.
6. **C** — `guard let ... else { return }` is the idiomatic early-exit unwrap: it keeps the happy path at the top indentation level and binds `name` as a non-optional for the rest of the scope. A nests the whole body one level deeper. B and D reintroduce a force-unwrap crash hazard.
7. **B** — `split(separator:)` omits empty subsequences by default (`omittingEmptySubsequences` defaults to `true`), so `"a,,b"` yields `["a", "b"]`, count `2`. Pass `omittingEmptySubsequences: false` if you need the empty field.
8. **C** — `Dictionary` and `Set` are unordered. Iterating one gives no stable order across runs or platforms. To produce deterministic output (as the mini-project requires) you must `sorted(...)` first. This is why the `wordfreq` ranking sorts explicitly.
9. **D** — The first three cases match arrays of length 0, 1, and 2. A three-element array falls through to `default`, returning `"many"`.
10. **B** — Force-unwrapping a `nil` is a runtime trap: the program halts with a fatal error. This is precisely the failure mode optionals were designed to make impossible *by accident* — `!` is you opting back into it deliberately, which is why we treat every `!` as a code smell.
11. **A** — `.executableTarget` builds a runnable binary (it has an entry point — `main.swift` or `@main`). A regular `.target` builds a library module that other targets import. The `wordfreq` mini-project uses exactly this split: `WordFreqCore` is a `.target`, `wordfreq` is an `.executableTarget`.
12. **B** — `#expect(condition)` records a failure and keeps going, so one test can check several things. `#require(condition)` records a failure and *throws*, stopping the test — which makes `try #require(someOptional)` the clean, force-unwrap-free way to get a non-optional value in test code.

</details>

---

If you scored under 8, re-read the lectures for the questions you missed — especially the value-vs-reference pair (Q2/Q3) and the optionals questions (Q4–Q6, Q10). If you scored 10 or above, you're ready for the [homework](./homework.md).
