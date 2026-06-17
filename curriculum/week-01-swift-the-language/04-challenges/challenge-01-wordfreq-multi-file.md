# Challenge 1 — Multi-file `wordfreq` with `--min-count`

**Time estimate:** ~90 minutes.

## Problem statement

Take the `wordfreq` mini-project — a `swift run wordfreq <file.txt>` CLI that counts word frequencies and prints the top 20 in a Markdown table — and make it grown-up. Right now it reads exactly one file. By the end of this challenge it will:

1. Accept **one or more** input files and **merge** their frequency counts into a single tally.
2. Accept a `--min-count N` flag that drops any word seen fewer than `N` times across all inputs.
3. Keep the existing single-file behaviour intact — `swift run wordfreq notes.txt` must still work exactly as before.
4. Keep the **Markdown table** output format unchanged (same header, same column alignment).
5. Keep every test green, and **add** tests for merging and for `--min-count`.
6. Build and test clean on **both** Linux and macOS.

The CLI surface you are targeting:

```bash
# One file, unchanged behaviour.
swift run wordfreq notes.txt

# Two files, merged counts.
swift run wordfreq chapter-01.txt chapter-02.txt

# Three files, but only words seen at least 5 times total.
swift run wordfreq a.txt b.txt c.txt --min-count 5

# The flag can appear anywhere on the line.
swift run wordfreq --min-count 3 a.txt b.txt
```

The `--top N` flag (defaulting to 20) is yours to keep from the mini-project's stretch goals if you added it; if you didn't, leave the top-20 behaviour as a constant. The required new flag is `--min-count`.

## Why this matters

This is the first time in C20 you parse your own command line by hand. You will **not** reach for `swift-argument-parser` yet — that arrives in Week 3, when the link-checker's flag surface justifies it. Parsing two flags and a variadic list of files by hand is a 25-line function, and writing it once teaches you exactly what a parser library does for you later. The dictionary-merge pattern (`total[word, default: 0] += count`) is the same one you used in the mini-project to count a single file; here you apply it one level up, across files.

## Acceptance criteria

- [ ] The package still has a `WordFreqCore` library target, a `wordfreq` executable target, and a `WordFreqCoreTests` test target.
- [ ] `swift build` prints `Build complete!` with **zero** warnings.
- [ ] `swift test` reports all tests passing, including **at least three new tests**: one for merging two count dictionaries, one for `--min-count` filtering, and one for argument parsing (files vs flags).
- [ ] `swift run wordfreq notes.txt` produces byte-for-byte the same output it did before this challenge (single-file behaviour preserved).
- [ ] `swift run wordfreq a.txt b.txt` merges counts: a word appearing 3 times in `a.txt` and 2 times in `b.txt` reports `5`.
- [ ] `swift run wordfreq a.txt b.txt --min-count 5` omits every word whose **total** merged count is below 5.
- [ ] The merge and filter logic lives in **`WordFreqCore`** (pure, testable functions), not in `main.swift`. `main.swift` only parses arguments, reads files, calls the library, and prints.
- [ ] **Zero force-unwraps (`!`)** in the source. Unreadable files and bad flag values produce a message on `stderr` and a non-zero exit code, not a crash.
- [ ] The Markdown table output format is unchanged.
- [ ] Code is committed to your Week 1 GitHub repo under `challenges/challenge-01/` (or as a branch of the mini-project repo — your call, but say which in the README).

## Suggested approach

### Step 1 — Lift merging into the library

Add a pure function to `WordFreqCore` that folds a list of per-file count dictionaries into one. This is the heart of the change, and it is trivial to test because it touches no files:

```swift
public static func merge(_ tallies: [[String: Int]]) -> [String: Int] {
    var total: [String: Int] = [:]
    for tally in tallies {
        for (word, count) in tally {
            total[word, default: 0] += count
        }
    }
    return total
}
```

### Step 2 — Add a `minCount` filter

You can filter inside `ranked(_:top:)` or as a separate step. Keep it explicit and testable:

```swift
public static func dropping(belowCount minCount: Int, from counts: [String: Int]) -> [String: Int] {
    counts.filter { $0.value >= minCount }
}
```

If `minCount <= 1`, this is a no-op — which is exactly what you want for the default.

### Step 3 — Parse the command line by hand

Walk the arguments once. Anything that starts with `--` is a flag (and consumes the next argument as its value); everything else is a file path. Returning a small struct keeps `main.swift` readable:

```swift
struct Options {
    var files: [String] = []
    var minCount: Int = 1
    var top: Int = 20
}

enum OptionError: Error, CustomStringConvertible {
    case expectedInteger(after: String)
    case unknownFlag(String)
    case noFiles

    var description: String {
        switch self {
        case .expectedInteger(let flag): return "expected an integer after \(flag)"
        case .unknownFlag(let flag): return "unknown flag: \(flag)"
        case .noFiles: return "usage: wordfreq <file.txt> [more.txt ...] [--min-count N] [--top N]"
        }
    }
}

func parseOptions(_ arguments: [String]) -> Result<Options, OptionError> {
    var options = Options()
    var index = arguments.startIndex
    while index < arguments.endIndex {
        let argument = arguments[index]
        switch argument {
        case "--min-count", "--top":
            index = arguments.index(after: index)
            guard index < arguments.endIndex, let value = Int(arguments[index]) else {
                return .failure(.expectedInteger(after: argument))
            }
            if argument == "--min-count" { options.minCount = value } else { options.top = value }
        case let flag where flag.hasPrefix("--"):
            return .failure(.unknownFlag(flag))
        default:
            options.files.append(argument)
        }
        index = arguments.index(after: index)
    }
    guard !options.files.isEmpty else { return .failure(.noFiles) }
    return .success(options)
}
```

Returning `Result<Options, OptionError>` instead of throwing is a deliberate choice here: a parsing failure is an expected outcome with a user-facing message, not an exceptional one. The failure type of `Result` must conform to `Error`, so we give it a small enum rather than a bare `String` (a bare `String` will not compile — `String` is not an `Error`). Conforming `OptionError` to `CustomStringConvertible` is what lets us print it straight to `stderr`. (Week 2 goes deep on `Result` vs `throws`; this is a preview of the decision.)

### Step 4 — Wire it together in `main.swift`

Read every file, tokenize each into a count dictionary, merge, drop below `minCount`, rank, render. On any unreadable file, write to `stderr` and exit non-zero — do not silently skip it unless you document that choice.

```swift
import Foundation
import WordFreqCore

let arguments = Array(CommandLine.arguments.dropFirst())

let options: Options
switch parseOptions(arguments) {
case .success(let parsed):
    options = parsed
case .failure(let message):
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

var tallies: [[String: Int]] = []
for path in options.files {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("error: cannot read file '\(path)'\n".utf8))
        exit(1)
    }
    tallies.append(WordFreq.count(text))
}

let merged = WordFreq.dropping(belowCount: options.minCount, from: WordFreq.merge(tallies))
let ranked = WordFreq.ranked(merged, top: options.top)
print(WordFreq.markdownTable(ranked))
```

### Step 5 — Test the new behaviour

```swift
import Testing
@testable import WordFreqCore

@Suite struct MergeTests {
    @Test func sumsCountsAcrossTallies() {
        let merged = WordFreq.merge([["x": 3, "y": 2], ["x": 2, "z": 1]])
        #expect(merged == ["x": 5, "y": 2, "z": 1])
    }

    @Test func mergingNothingIsEmpty() {
        #expect(WordFreq.merge([]).isEmpty)
    }
}

@Suite struct MinCountTests {
    @Test func dropsWordsBelowThreshold() {
        let kept = WordFreq.dropping(belowCount: 3, from: ["a": 5, "b": 2, "c": 3])
        #expect(kept == ["a": 5, "c": 3])
    }

    @Test func thresholdOfOneKeepsEverything() {
        let counts = ["a": 1, "b": 1]
        #expect(WordFreq.dropping(belowCount: 1, from: counts) == counts)
    }
}
```

## Verifying on both platforms

On macOS:

```bash
swift test
```

On Linux, either install the toolchain (see Exercise 1) or use the official Docker image without installing anything:

```bash
docker run --rm -v "$PWD:/work" -w /work swift:6.1 swift test
```

If both print `Test run with N tests ... passed`, you are done.

## Stretch

- Add a `--ignore-case false` flag so the tokenizer can preserve case. (Default stays case-folded.) This forces you to thread an option down into `WordFreqCore.tokenize`, which is good practice for keeping a pure core configurable.
- Add a `--stopwords <file>` flag that loads a newline-delimited list of words to exclude (the, a, of, and ...). Filter them out before ranking. Test that an empty stopwords file is a no-op.
- Print, on `stderr`, a one-line summary after the table: `# 4213 words, 871 distinct, 2 files, min-count 5`. Keep it on `stderr` so piping the table into a Markdown file stays clean.
- Make file reads **concurrent**: read all files in parallel and merge the results. You don't have the concurrency vocabulary yet (that's Week 3), so this is a genuine stretch — but if you've seen `async let` elsewhere, try it and note where it got hard.

## What "done" looks like

```bash
$ printf "the cat sat\n" > a.txt
$ printf "the dog ran the cat\n" > b.txt
$ swift run wordfreq a.txt b.txt --min-count 2
| Rank | Word | Count |
| ---: | :--- | ----: |
| 1 | the | 3 |
| 2 | cat | 2 |
```

`the` appears once in `a.txt` and twice in `b.txt` (total 3); `cat` appears once in each (total 2); everything else falls below `--min-count 2` and is dropped. The table format is identical to the single-file mini-project. That is the whole game.
