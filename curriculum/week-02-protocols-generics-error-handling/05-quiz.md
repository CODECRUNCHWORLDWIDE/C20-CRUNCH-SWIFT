# Week 2 — Quiz

Thirteen multiple-choice questions. Take it with your lecture notes closed. Aim for 10/13 before moving to Week 3. Answer key at the bottom — don't peek.

---

**Q1.** Which statement best captures why a Swift protocol is *not* a Java interface?

- A) Protocols are slower than interfaces because they always box their values.
- B) Protocols can be adopted by value types (`struct`/`enum`), can carry default implementations via extensions, and are usually used as compile-time generic constraints — not just as boxed run-time supertypes.
- C) Protocols can only be adopted by classes, exactly like Java interfaces.
- D) Protocols and interfaces are identical; "protocol" is just Apple's marketing name.

---

**Q2.** Given:

```swift
protocol Greeter { func hello() -> String }
extension Greeter {
    func hello() -> String { "ext hello" }
    func goodbye() -> String { "ext bye" }
}
struct French: Greeter {
    func hello() -> String { "bonjour" }
    func goodbye() -> String { "au revoir" }
}
let g: Greeter = French()
print(g.hello(), g.goodbye())
```

What does this print?

- A) `bonjour au revoir`
- B) `ext hello ext bye`
- C) `bonjour ext bye`
- D) `ext hello au revoir`

---

**Q3.** Why does `let c: Container = IntStack()` fail to compile when `Container` declares `associatedtype Item`?

- A) Because `IntStack` is a `struct` and protocols require classes.
- B) Because a protocol with an associated type is a PAT — the compiler cannot lay out a value of it without knowing the concrete `Item`. Use it as a constraint, `some`, or `any`.
- C) Because `Container` was not marked `@objc`.
- D) Because `IntStack` did not write `typealias Item = Int`.

---

**Q4.** What is the run-time cost of returning `some View` from a SwiftUI `body`?

- A) A heap allocation and a dynamic dispatch per call.
- B) Zero — the concrete type is fixed and known at compile time, so it is specialised and inlined.
- C) The same as `any View`; the keywords are interchangeable.
- D) A witness-table lookup, but no allocation.

---

**Q5.** Which line genuinely *requires* `any` and cannot be expressed with `some`?

- A) `func makeShape() -> some Shape { Circle() }`
- B) `func describe(_ s: some Shape) -> String`
- C) `let shapes: [any Shape] = [Circle(), Square()]`
- D) `var body: some View { Text("hi") }`

---

**Q6.** This does not compile. Why?

```swift
func make(_ big: Bool) -> some Shape {
    big ? Square(side: 10) : Circle(radius: 1)
}
```

- A) `some` cannot be used in return position.
- B) An opaque return type must be the *same* concrete type on every path; this returns `Square` on one branch and `Circle` on the other.
- C) `Shape` must be a class for `some` to work.
- D) You cannot use a ternary with `some`.

---

**Q7.** What is the idiomatic way to model a closed set of failure modes you will switch over exhaustively?

- A) Subclasses of `NSError`.
- B) An `enum` conforming to `Error`, one case per failure, with associated values for detail.
- C) A `struct` with a `String` message field.
- D) Throwing plain `String` values.

---

**Q8.** Given a function `func load() throws -> Data`, which expression turns a thrown error into `nil` and discards the error value?

- A) `try! load()`
- B) `try? load()`
- C) `try load()`
- D) `Result { try load() }`

---

**Q9.** When is `try!` defensible?

- A) Any time you are confident the call usually succeeds.
- B) When the call touches the network but you added a retry.
- C) Over a value whose success is an invariant the type system cannot see — e.g. decoding a resource you shipped inside your own app bundle, where a failure means your build is broken.
- D) Whenever you want to silence a compiler error quickly.

---

**Q10.** What does `Result { try someThrowingCall() }` produce?

- A) A `Result<Success, Never>` that can never fail.
- B) A `Result<Success, any Error>` capturing either the returned value or the thrown error.
- C) The success value directly, or `nil` on failure.
- D) It re-throws immediately; it does not return a `Result`.

---

**Q11.** Given:

```swift
let r: Result<Int, MyError> = .success(10)
let doubled = r.map { $0 * 2 }
```

What is `doubled`?

- A) `Result<Int, MyError>.success(20)`
- B) `20`
- C) `Result<Int, MyError>.failure(...)`
- D) It does not compile; `Result` has no `map`.

---

**Q12.** A generic type `Stack<Element>` should be `Equatable` only when `Element` is `Equatable`. Which feature expresses this?

- A) Inheritance from an `EquatableStack` base class.
- B) Conditional conformance: `extension Stack: Equatable where Element: Equatable`.
- C) `@objc` on the `==` operator.
- D) It is impossible; generic types cannot be `Equatable`.

---

**Q13.** You are designing a cache whose eviction policy (LRU vs TTL) is chosen once, at construction, and never varies for the cache's lifetime. The policy protocol has an `associatedtype Key`. Which is the *best* way to hold the policy?

- A) `any EvictionPolicy<Key>` — it is the most flexible.
- B) A generic type parameter (`Cache<…, Policy>` with `where Policy.Key == Key`) — the policy is fixed, so the generic preserves the concrete type and pays no existential box.
- C) A subclass of an `EvictionPolicy` base class.
- D) A global mutable variable holding the current policy.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — Protocols are value-type-friendly, carry default implementations, support associated types, and are primarily compile-time constraints. The boxed-supertype use (`any`) is one mode, not the defining one. (Lecture 1 §1.)
2. **C** — `hello()` is a *requirement*, so it dispatches dynamically to `French.hello()` → `bonjour`. `goodbye()` is *extension-only* (not a requirement), so with a static type of `Greeter` it resolves to the extension → `ext bye`. This is the dispatch gotcha. (Lecture 1 §3.)
3. **B** — A PAT has no fixed layout until the associated type is known, so it cannot be a bare type. Use it as a constraint, `some`, or `any`. (Lecture 1 §5.)
4. **B** — `some` is zero-cost: one concrete (if unnamed) type, specialised and inlined. That is exactly why SwiftUI uses it. (Lecture 2 §2.)
5. **C** — A heterogeneous array of *different* concrete types needs the existential box. The others all have a single, fixed concrete type and are correctly `some`. (Lecture 2 §3.)
6. **B** — Every `return` from an opaque function must produce the *same* concrete type. Two different types is the signal you wanted `any`. (Lecture 2 §2.)
7. **B** — An `enum: Error` is the idiomatic Swift error domain: exhaustive, typed payloads, testable. (Lecture 2 §6.)
8. **B** — `try?` converts a throw to `nil` and discards the error. (Lecture 2 §6.)
9. **C** — `try!` is only defensible over an invariant the compiler cannot see, like a bundled resource. Over network/file/user input it is a latent crash. (Lecture 2 §6.)
10. **B** — The throwing `Result` initializer captures success or the thrown error as `Result<Success, any Error>`. (Lecture 2 §7.)
11. **A** — `map` transforms the success and leaves the type a `Result`; it does not unwrap. (Lecture 2 §7.)
12. **B** — Conditional conformance ties the conformance to a constraint on the element. `Array` in the standard library does exactly this. (Lecture 1 §6.)
13. **B** — A fixed, construction-time strategy with no run-time heterogeneity should be a generic parameter (zero cost, type preserved), not `any` (box + dynamic dispatch on the hot path). (Lecture 2 §4; challenge.)

</details>

---

If you scored under 10, re-read the lectures for the questions you missed — especially the dispatch gotcha (Q2) and the `some`/`any` decision matrix (Q5, Q6, Q13). If you scored 12 or 13, you're ready to dive into the [homework](./06-homework.md).
