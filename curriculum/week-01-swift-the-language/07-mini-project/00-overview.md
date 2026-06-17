# Mini-Project — `wordfreq` CLI

> Build a `swift run wordfreq <file.txt>` command-line tool that counts word frequencies in a text file, prints the top 20 in a Markdown table, and is fully unit-tested with **Swift Testing**. The package must cross-compile and run identically on **Linux and macOS** using only the open-source Swift toolchain and the standard library + `Foundation`. No third-party dependencies.

This is the capstone of Week 1, and it is the project the rest of Phase I quietly builds on. The whole point is to internalize the open-source Swift surface — SwiftPM layout, a library target plus an executable target, value-type collections, optionals without force-unwraps, and a Swift Testing suite — without any framework wallpaper hiding what is happening. You read a file, you split it into words, you count them, you sort them, you print a table. Every line of it is yours.

**Estimated time:** ~8.5 hours (split across Thursday, Friday, and Saturday in the suggested schedule).

---

## What you will build

A package called `wordfreq` whose executable reads a single text file and prints the 20 most frequent words as a Markdown table:

```bash
swift run wordfreq sample.txt
```

```
| Rank | Word | Count |
| ---: | :--- | ----: |
| 1 | the | 142 |
| 2 | and | 97 |
| 3 | of | 88 |
| 4 | to | 81 |
| 5 | a | 74 |
...
| 20 | with | 19 |
```

The counting rules are deliberately simple and fully specified (no "do whatever you think is reasonable" — determinism is the point):

- **Tokenization.** Split the text on any character that is *not* a Unicode letter or a digit. (`"don't"` becomes `don` and `t`; that is fine for Week 1 — we are not building a linguistics engine.)
- **Case folding.** Lowercase every token (`"The"` and `"the"` are the same word).
- **Empty tokens.** Drop them — runs of punctuation must not produce empty words.
- **Ranking.** Sort by count descending. Break ties by the word ascending (alphabetical), so the output is *deterministic* and identical on every machine and every run.
- **Top N.** Print the top 20 (or fewer, if the file has fewer distinct words).

By the end you'll have a public GitHub repo of ~150–250 lines of Swift (excluding tests) that handles a missing file gracefully, never crashes on bad input, and builds green on both platforms.

---

## Why a library target *and* an executable target

The single most important structural decision in this project: **all the logic lives in a `WordFreqCore` library target, and the executable target is a thin shell.** The executable's job is to parse arguments, read the file, call the library, and print. Everything testable — tokenizing, counting, ranking, rendering — is a pure function in the library.

You cannot unit-test code that lives inside `main.swift`. SwiftPM does not let a test target import an executable target's `main`. So if you put your logic in `main.swift`, you have made it untestable, and this project requires tests. Put the logic in the library. This is not a Week 1 quirk — it is how every serious SwiftPM project is laid out, and the Phase I integration project (Week 6) depends on you having this reflex.

The exact public API your `WordFreqCore` library must expose (the challenge and the tests both depend on these signatures):

```swift
public enum WordFreq {
    /// Tokenize text into lowercased words, dropping empty tokens.
    public static func tokenize(_ text: String) -> [String]

    /// Count occurrences of each word in the text.
    public static func count(_ text: String) -> [String: Int]

    /// Merge several count dictionaries into one (sums per word).
    public static func merge(_ tallies: [[String: Int]]) -> [String: Int]

    /// Drop any word whose count is below `minCount`.
    public static func dropping(belowCount minCount: Int, from counts: [String: Int]) -> [String: Int]

    /// Rank counts: by count descending, then word ascending; take the top `top`.
    public static func ranked(_ counts: [String: Int], top: Int) -> [(word: String, count: Int)]

    /// Render ranked rows as a Markdown table (the exact format shown above).
    public static func markdownTable(_ ranked: [(word: String, count: Int)]) -> String
}
```

`merge` and `dropping` are not used by the single-file mini-project, but the public API includes them now so that **Challenge 1** can extend the CLI to multiple files and a `--min-count` flag without touching the library's shape. Write them now; test them now; the challenge will thank you.

---

## Rules

- **You may** read the Swift book, the standard-library docs, the SwiftPM docs, the lecture notes, and the Swift Testing docs.
- **You may NOT** depend on any third-party SwiftPM package. No `swift-argument-parser` (that's Week 3), no `swift-collections`, no `Yams`. Standard library plus `Foundation` only.
- Parse the single command-line argument by hand — it is one line: `CommandLine.arguments`.
- **You must** treat every `swift build` warning as a defect. A clean build prints `Build complete!` with no diagnostics above it.
- **Zero force-unwraps (`!`)** in the source. A missing or unreadable file produces a message on `stderr` and a non-zero exit code, not a crash.
- `// swift-tools-version: 6.1` in the manifest. The package builds under Swift 6 language mode.

---

## Acceptance criteria

- [ ] A new public GitHub repo named `c20-week-01-wordfreq-<yourhandle>`.
- [ ] Package layout matches the C20 standard:
  ```
  wordfreq/
  ├── Package.swift
  ├── .gitignore                    (ignores .build/)
  ├── README.md
  ├── samples/
  │   └── sample.txt
  ├── Sources/
  │   ├── WordFreqCore/
  │   │   └── WordFreq.swift
  │   └── wordfreq/
  │       └── main.swift
  └── Tests/
      └── WordFreqCoreTests/
          ├── TokenizeTests.swift
          ├── CountTests.swift
          └── RankAndRenderTests.swift
  ```
- [ ] `swift build` prints `Build complete!` with **zero** warnings.
- [ ] `swift test` reports all tests passing — **at least 12** tests across tokenizing, counting, merging, dropping, ranking, and rendering.
- [ ] `swift run wordfreq samples/sample.txt` prints a Markdown table with the correct top-20 (or fewer) rows in the exact format above.
- [ ] A missing file prints `error: cannot read file '<path>'` to `stderr` and exits non-zero — it does **not** crash.
- [ ] No argument at all prints a one-line usage message to `stderr` and exits non-zero.
- [ ] Ranking is deterministic: ties broken alphabetically, so the output is byte-for-byte stable across runs and platforms.
- [ ] **Zero `!` force-unwrap operators** in the source.
- [ ] The package builds and tests clean on **both** Linux and macOS (use the Docker image for the platform you don't own — see below).
- [ ] Your `README.md` includes a project paragraph, the setup-from-fresh-clone commands, the sample file, the expected output, and a "Things I learned" section with at least three specific items.

---

## Suggested order of operations

Build it incrementally. Each phase ends with a green build and a commit.

### Phase 1 — Scaffold the package (~45 min)

```bash
mkdir wordfreq && cd wordfreq
swift package init --type executable --name wordfreq
git init
printf ".build/\n" > .gitignore
```

The default template gives you one executable target. You need to split it into a library + an executable. Rewrite `Package.swift` to declare two source targets and one test target:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "wordfreq",
    targets: [
        .target(name: "WordFreqCore"),
        .executableTarget(
            name: "wordfreq",
            dependencies: ["WordFreqCore"]
        ),
        .testTarget(
            name: "WordFreqCoreTests",
            dependencies: ["WordFreqCore"]
        ),
    ]
)
```

Then create the directories SwiftPM expects (it maps a target name to `Sources/<name>/` and `Tests/<name>/` by convention):

```bash
mkdir -p Sources/WordFreqCore Sources/wordfreq Tests/WordFreqCoreTests
rm -rf Sources/wordfreq/wordfreq.swift   # delete whatever the template left
```

Confirm the structure with `swift package describe`. Commit: `Scaffold wordfreq package: core lib + executable + tests`.

### Phase 2 — Tokenize and count (~1.5 h)

In `Sources/WordFreqCore/WordFreq.swift`, implement `tokenize` and `count`. Tokenize by splitting on anything that is not a letter or digit, then lowercasing. The standard library gives you everything you need:

```swift
public enum WordFreq {
    public static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    public static func count(_ text: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        for word in tokenize(text) {
            counts[word, default: 0] += 1
        }
        return counts
    }
}
```

Two idioms worth pausing on:

- `split(whereSeparator:)` returns `[Substring]`, slices that share the parent string's storage. `.map(String.init)` copies each into its own `String` so the tokens don't pin the whole input string in memory.
- `counts[word, default: 0] += 1` is the canonical Swift count-up. `Dictionary`'s `subscript(_:default:)` reads `0` when the key is absent, then the `+= 1` writes the incremented value back. No `if counts[word] == nil` dance.

Write `TokenizeTests.swift` and `CountTests.swift` now. Commit: `Tokenize + count, with tests`.

### Phase 3 — Merge and drop (~45 min)

These two are short and pure. They exist so the challenge can build on them:

```swift
extension WordFreq {
    public static func merge(_ tallies: [[String: Int]]) -> [String: Int] {
        var total: [String: Int] = [:]
        for tally in tallies {
            for (word, count) in tally {
                total[word, default: 0] += count
            }
        }
        return total
    }

    public static func dropping(belowCount minCount: Int, from counts: [String: Int]) -> [String: Int] {
        counts.filter { $0.value >= minCount }
    }
}
```

Test `merge` (two dictionaries with an overlapping key sum correctly; merging `[]` is empty) and `dropping` (a threshold of 1 is a no-op; a higher threshold removes the right keys). Commit: `Merge + dropping, with tests`.

### Phase 4 — Rank and render (~1.5 h)

Ranking is where determinism lives. Sort by count descending, then by word ascending so ties resolve the same way every time:

```swift
extension WordFreq {
    public static func ranked(_ counts: [String: Int], top: Int) -> [(word: String, count: Int)] {
        counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(max(0, top))
            .map { (word: $0.key, count: $0.value) }
    }

    public static func markdownTable(_ ranked: [(word: String, count: Int)]) -> String {
        var lines = [
            "| Rank | Word | Count |",
            "| ---: | :--- | ----: |",
        ]
        for (index, row) in ranked.enumerated() {
            lines.append("| \(index + 1) | \(row.word) | \(row.count) |")
        }
        return lines.joined(separator: "\n")
    }
}
```

Why sort the dictionary rather than iterate it directly? **A `Dictionary` has no defined iteration order in Swift.** If you print `for (word, count) in counts`, the order can differ between runs and between platforms — your tests would be flaky and your two-platform requirement would fail. Sorting is what makes the output reproducible.

Write `RankAndRenderTests.swift`: rank a small dictionary and assert the order, including a deliberate tie to prove the alphabetical tiebreak. Assert the exact Markdown header lines. Commit: `Rank + Markdown render, with tests`.

### Phase 5 — The executable shell (~1 h)

`Sources/wordfreq/main.swift` is the thin layer. It does I/O and nothing else:

```swift
import Foundation
import WordFreqCore

let arguments = Array(CommandLine.arguments.dropFirst())

guard let path = arguments.first else {
    FileHandle.standardError.write(Data("usage: wordfreq <file.txt>\n".utf8))
    exit(2)
}

guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
    FileHandle.standardError.write(Data("error: cannot read file '\(path)'\n".utf8))
    exit(1)
}

let counts = WordFreq.count(text)
let ranked = WordFreq.ranked(counts, top: 20)
print(WordFreq.markdownTable(ranked))
```

Note `try? String(contentsOfFile:encoding:)` returns an `Optional` — `nil` on any read error — and the `guard let` turns that into a clean message-and-exit. No `try!`, no force-unwrap, no crash. Commit: `Executable shell: read file, print table`.

### Phase 6 — Sample data + smoke (~30 min)

Drop a paragraph or two of real prose into `samples/sample.txt` (the opening of a public-domain book works well — Project Gutenberg). Then:

```bash
swift run wordfreq samples/sample.txt
swift run wordfreq does-not-exist.txt   # should print the error to stderr and exit 1
swift run wordfreq                        # should print usage and exit 2
echo "exit code: $?"
```

Paste the real top-20 output into your README under "Example." Commit: `Sample data + README example`.

### Phase 7 — Cross-platform + polish (~1 h)

Verify on the platform you don't own using Docker (no install required):

```bash
docker run --rm -v "$PWD:/work" -w /work swift:6.1 swift test
```

Then a release build to confirm nothing depended on debug behavior:

```bash
swift build -c release
.build/release/wordfreq samples/sample.txt | head
```

Push to GitHub. Optionally add a one-line CI workflow that runs `swift test` on push (required from Week 4; nice to have now). Commit: `Cross-platform verification + release build`.

---

## Example expected output

For a `samples/sample.txt` containing the first paragraph of *Pride and Prejudice*:

```
$ swift run wordfreq samples/sample.txt
| Rank | Word | Count |
| ---: | :--- | ----: |
| 1 | a | 5 |
| 2 | of | 4 |
| 3 | is | 3 |
| 4 | the | 3 |
| 5 | in | 2 |
...
```

Your numbers depend on your chosen sample. The *format* is fixed; the counts are whatever your file produces. The two header lines must be byte-for-byte as shown.

---

## Rubric

| Criterion | Weight | What "great" looks like |
|----------|-------:|-------------------------|
| Builds and runs | 25% | `swift build`, `swift test`, `swift run` all clean on a fresh clone, on both Linux and macOS |
| Structure | 20% | Logic lives in `WordFreqCore`; `main.swift` is a thin I/O shell; the public API matches the spec exactly |
| Crash-safety | 10% | Zero force-unwraps; missing/unreadable file handled with a message and a non-zero exit |
| Test coverage | 20% | At least 12 Swift Testing tests, including a deliberate tie in the ranking test |
| Determinism | 15% | Output is byte-for-byte identical across runs and platforms; ties broken alphabetically |
| README quality | 10% | Someone unfamiliar can clone and run in under five minutes |

---

## Stretch (optional)

- Add a `--top N` flag (default 20). This is the natural first step toward Challenge 1 and is one extra branch in your argument handling.
- Add a `--json` flag that prints the ranked words as a JSON array instead of a Markdown table. Define a small `Codable` struct and encode it with `JSONEncoder` from `Foundation`.
- Read from `stdin` when no file path is given, so `cat book.txt | swift run wordfreq` works. (`String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8)`.)
- Benchmark `tokenize` against a 1-million-word file. (You get `os_signpost` and proper profiling in Phase III — for now just time it with `Date()` and see whether `split(whereSeparator:)` holds up.)
- Build a fully static Linux binary with `swift build -c release --static-swift-stdlib` and note the size difference. This is the deploy artifact you'll care about in Week 5 (Vapor on Linux).

---

## What this prepares you for

- **Challenge 1** extends *this exact package* to multiple files and a `--min-count` flag. The `merge` and `dropping` functions you write here are what make that a 30-line change instead of a rewrite.
- **Week 2** takes the `WordFreq` enum and makes its operations generic and protocol-backed. The pure-library-target discipline you build here is the prerequisite.
- **Week 3** turns the synchronous file read into a concurrent, cancellable read across many files.
- **Week 6** (the Phase I integration project) shares a SwiftPM library target between a CLI and a Vapor server. The "logic in a library target, I/O in the executable" split you practice here is *the* pattern that move depends on.

---

## Resources

- *The Swift Programming Language — Collection Types*: <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/>
- *Swift Package Manager documentation*: <https://www.swift.org/documentation/package-manager/>
- *Swift Testing*: <https://developer.apple.com/documentation/testing>
- *`String` and `Character`*: <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- *Project Gutenberg* (public-domain sample text): <https://www.gutenberg.org/>

---

## Submission

When done:

1. Push your repo to GitHub with a public URL.
2. Make sure `README.md` includes the setup commands and the example output.
3. Make sure `swift build` and `swift test` are green on a fresh clone — and on the *other* platform via the Docker image.
4. Post the repo URL in your cohort tracker. You did real work; show it.
