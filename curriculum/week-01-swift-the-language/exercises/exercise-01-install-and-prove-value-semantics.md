# Exercise 1 — Install the Toolchain and Prove Value Semantics

**Goal:** Install the open-source Swift toolchain on your machine (Linux or macOS), confirm it runs, explore it in the REPL, then scaffold a SwiftPM executable and prove — in running code — the difference between value types (`struct`) and reference types (`class`). No Xcode. No IDE wizards. Just you and the `swift` CLI.

**Estimated time:** 40 minutes.

---

## Setup

You need the Swift 6.1 toolchain. If you do not have it yet, install it now.

### Linux (Ubuntu 22.04 / 24.04)

```bash
curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
tar zxf swiftly-$(uname -m).tar.gz
./swiftly init
# Restart your shell (or source the env file Swiftly prints), then:
swiftly install latest
swiftly use latest
```

### macOS (no Xcode required)

```bash
curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
~/.swiftly/bin/swiftly init
swiftly install latest && swiftly use latest
```

(If you already have Xcode installed, `xcode-select --install` followed by `swift --version` is enough — Xcode bundles a toolchain.)

### Verify

```bash
swift --version
```

You should see `Swift version 6.1` and a target line. If you do not, stop and fix that before going further. Every example this week assumes `swift --version` reports 6.1.

You also need Git. `git --version` should print a real version.

---

## Step 1 — Explore in the REPL

Run the REPL and type the following lines one at a time. **Read the type the REPL prints after each one** — that is the point of this step.

```bash
swift
```

```
  1> let xs = [3, 1, 2]
  2> xs.sorted()
  3> Int("42")
  4> Int("not a number")
  5> import Foundation
  6> Date()
  7> :quit
```

Notice that line 3 prints `Int? = 42` and line 4 prints `Int? = nil`. The conversion returns an **`Optional`**, because turning a string into an integer can fail. This is the optional model from Lecture 1, demonstrated live. Write down (in your own words) why `Int(String)` returns `Int?` and not `Int`.

---

## Step 2 — Scaffold a package

```bash
mkdir ValueVsRef && cd ValueVsRef
swift package init --type executable --name ValueVsRef
git init
```

You now have a `Package.swift`, a `Sources/` directory, and a `Tests/` directory. Add a `.gitignore`:

```bash
printf '.build/\n.swiftpm/\n.DS_Store\n' > .gitignore
git add .
git commit -m "Initial package"
```

Build and run the template to confirm the toolchain works end to end:

```bash
swift build
swift run
```

You should see `Build complete!` and then `Hello, world!`.

---

## Step 3 — Write the value-vs-reference proof

Replace the contents of your executable's source file (`Sources/main.swift`, or `Sources/ValueVsRef/main.swift` depending on your toolchain's template — run `ls Sources` to find it) with this:

```swift
// A side-by-side proof: structs are values (copied), classes are references (shared).

struct PointValue {
    var x: Int
    var y: Int
}

final class PointRef {
    var x: Int
    var y: Int
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

print("== Value type (struct) ==")
var v1 = PointValue(x: 1, y: 2)
var v2 = v1            // v2 is an independent COPY
v2.x = 99
print("v1.x = \(v1.x)   // expect 1  — the original is untouched")
print("v2.x = \(v2.x)   // expect 99")

print("== Reference type (class) ==")
let r1 = PointRef(x: 1, y: 2)
let r2 = r1            // r2 references the SAME instance
r2.x = 99
print("r1.x = \(r1.x)   // expect 99 — both names point at one instance")
print("r2.x = \(r2.x)   // expect 99")
print("r1 === r2 ? \(r1 === r2)   // expect true — same identity")

print("== let on a value type is total immutability ==")
let frozen = PointValue(x: 5, y: 5)
// Uncomment the next line and rebuild to SEE the compile error, then re-comment it:
// frozen.x = 10   // error: cannot assign to property: 'frozen' is a 'let' constant
print("frozen = (\(frozen.x), \(frozen.y))   // cannot be mutated; the compiler enforces it")
```

Build and run:

```bash
swift build
swift run
```

Expected output:

```
== Value type (struct) ==
v1.x = 1   // expect 1  — the original is untouched
v2.x = 99   // expect 99
== Reference type (class) ==
r1.x = 99   // expect 99 — both names point at one instance
r2.x = 99   // expect 99
r1 === r2 ? true   // expect true — same identity
== let on a value type is total immutability ==
frozen = (5, 5)   // cannot be mutated; the compiler enforces it
```

---

## Step 4 — See the compile error on purpose

Uncomment the `frozen.x = 10` line. Run `swift build`. You should see, and you should read carefully:

```
error: cannot assign to property: 'frozen' is a 'let' constant
```

This is the compiler proving Lecture 1's claim: a `let` on a value type freezes the entire value. Re-comment the line so the package builds clean again.

Now change `frozen` to a reference type for contrast: temporarily replace `let frozen = PointValue(...)` logic with a `let r3 = PointRef(x: 5, y: 5); r3.x = 10` and confirm it compiles — a `let` on a *reference* only freezes the reference, not the instance's `var` properties. Then revert. Write one sentence in your notes explaining the difference.

---

## Step 5 — Add a test that documents the semantics

Replace `Tests/ValueVsRefTests/ValueVsRefTests.swift` with a Swift Testing target that asserts the copy behaviour. (If the directory name differs, match whatever `swift package init` created.)

```swift
import Testing

struct PointValue { var x: Int; var y: Int }

@Suite struct ValueSemanticsTests {
    @Test func structAssignmentCopies() {
        var a = PointValue(x: 1, y: 2)
        var b = a
        b.x = 99
        #expect(a.x == 1)   // the original did not change
        #expect(b.x == 99)
    }

    @Test func arrayIsAValueTypeWithCopyOnWrite() {
        var a = [1, 2, 3]
        var b = a
        b.append(4)
        #expect(a == [1, 2, 3])      // a untouched — copy-on-write forked b's buffer
        #expect(b == [1, 2, 3, 4])
    }
}
```

Run the tests:

```bash
swift test
```

You should see:

```
✔ Test run with 2 tests passed after 0.00X seconds.
```

Commit your work.

```bash
git add .
git commit -m "Value vs reference proof + tests"
```

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `swift --version` reports 6.1 on your machine.
- [ ] You can describe, in your own words, why `Int("42")` returns `Int?` and not `Int`.
- [ ] You have a `ValueVsRef/` package with `Package.swift`, `Sources/`, `Tests/`, and a `.gitignore` that excludes `.build/`.
- [ ] `swift build` prints `Build complete!` with no warnings.
- [ ] `swift run` prints the expected output above.
- [ ] You saw the `'frozen' is a 'let' constant` compile error with your own eyes, then fixed it.
- [ ] `swift test` reports 2 passing tests.
- [ ] You have at least 2 Git commits with sensible messages.

---

## Stretch

- Prove cross-platform: if you are on macOS, run your package inside the Linux Docker image and confirm identical output:
  ```bash
  docker run --rm -v "$PWD":/work -w /work swift:6.1 swift test
  ```
- Add a third type — an `enum` with associated values — and a test that proves it is also a value type (assignment copies it).
- In the REPL, type `MemoryLayout<PointValue>.size` and `MemoryLayout<PointValue>.stride`. What do they report, and why might they differ?

---

## Hints

<details>
<summary>If `swift package init` produces a layout you don't recognize</summary>

SwiftPM's templates have changed across toolchain versions. Run `ls -R Sources Tests` to see exactly what was generated, and adjust the file paths in the steps above to match. The key invariant: your executable code is under `Sources/`, your tests under `Tests/<TargetName>Tests/`, and `Package.swift` declares an `.executableTarget` and a `.testTarget`.

</details>

<details>
<summary>If `swift test` can't find the `Testing` module</summary>

`import Testing` requires a Swift 6 toolchain. Confirm `swift --version` shows 6.x. If you are stuck on an older toolchain, run `swiftly install latest && swiftly use latest`.

</details>

<details>
<summary>If the REPL won't start on Linux</summary>

The REPL needs the LLDB component of the toolchain, which ships in the official builds. If `swift` with no arguments errors, you likely have a partial install — reinstall via Swiftly. As a fallback, you can use the Docker image: `docker run --rm -it swift:6.1 swift`.

</details>

---

When this exercise feels comfortable, move to [Exercise 2 — Optionals](exercise-02-optionals.swift).
