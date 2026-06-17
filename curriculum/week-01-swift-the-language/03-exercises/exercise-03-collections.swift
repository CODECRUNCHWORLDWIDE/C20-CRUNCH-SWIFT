// Exercise 3 — Collections
//
// Goal: Transform a small dataset using every core Swift collection type —
//       String, Array, Dictionary, Set, ranges, and tuples — and read the
//       inline comments that explain what type inference deduced and why.
//
// Estimated time: 40 minutes.
//
// HOW TO RUN THIS FILE
//
//   swift exercise-03-collections.swift
//
// (Or compile first: swiftc exercise-03-collections.swift -o ex3 && ./ex3)
//
// This file is COMPLETE and CORRECT — it runs as written and prints the
// expected output at the bottom. Read it top to bottom, paying attention to
// the `// inferred:` comments, then do the "YOUR TURN" drill at the end.
//
// WHAT TO INTERNALISE
//
//   - String is a value type and is NOT an Array of Characters; you iterate
//     Characters (grapheme clusters), not bytes.
//   - Array, Dictionary, and Set are value types with copy-on-write.
//   - Ranges (a..<b and a...b) are first-class values you can iterate and slice.
//   - Tuples are lightweight, unnamed-or-named, value-type bundles.

import Foundation

// ----------------------------------------------------------------------------
// The sample dataset: a few lines of "score" records.
// ----------------------------------------------------------------------------

let raw = """
ada,90,math
grace,85,cs
edsger,95,cs
ada,70,cs
grace,100,math
linus,88,cs
"""
// inferred: `raw` is a String (a multi-line string literal).

// ----------------------------------------------------------------------------
// 1. String -> [String]: split into lines, then into fields.
// ----------------------------------------------------------------------------

let lines = raw.split(separator: "\n").map(String.init)
// inferred: `split` returns [Substring]; `.map(String.init)` makes it [String].
// We convert to String so downstream code isn't tied to the parent string's storage.

// A tuple type alias documents the shape of a parsed record.
typealias Record = (name: String, score: Int, subject: String)

func parse(_ line: String) -> Record? {
    let fields = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    // inferred: `fields` is [String].
    guard fields.count == 3, let score = Int(fields[1]) else { return nil }
    return (name: fields[0], score: score, subject: fields[2])
}

let records: [Record] = lines.compactMap(parse)
// inferred without the annotation: [(name: String, score: Int, subject: String)].
// `compactMap` drops the nil results, so malformed lines are silently skipped.

// ----------------------------------------------------------------------------
// 2. Array operations: filter, map, sorted, reduce.
// ----------------------------------------------------------------------------

let csScores = records
    .filter { $0.subject == "cs" }      // keep only cs records
    .map { $0.score }                   // project to just the scores
    .sorted(by: >)                      // descending
// inferred: [Int].

let total = records.reduce(0) { $0 + $1.score }
// inferred: Int. reduce folds the records into a running sum.

let average = Double(total) / Double(records.count)
// inferred: Double. We convert both operands to Double to avoid integer division.

// ----------------------------------------------------------------------------
// 3. Dictionary: group and aggregate.
// ----------------------------------------------------------------------------

// Build a [subject: [scores]] dictionary using Dictionary(grouping:by:).
let scoresBySubject: [String: [Int]] = Dictionary(grouping: records, by: { $0.subject })
    .mapValues { group in group.map(\.score) }
// inferred (without the annotation): [String: [Int]].
// `\.score` is a key-path: shorthand for `{ $0.score }`.

// Best score per subject, via mapValues + max.
let bestBySubject: [String: Int] = scoresBySubject.mapValues { scores in
    scores.max() ?? 0   // `max()` returns Int?; ?? handles the empty case
}

// ----------------------------------------------------------------------------
// 4. Set: distinct values and set algebra.
// ----------------------------------------------------------------------------

let names: Set<String> = Set(records.map(\.name))
// inferred without annotation: Set<String>. Duplicates collapse: "ada" and
// "grace" each appear twice in the data but once in the Set.

let subjects: Set<String> = Set(records.map(\.subject))

let mathTakers: Set<String> = Set(records.filter { $0.subject == "math" }.map(\.name))
let csTakers:   Set<String> = Set(records.filter { $0.subject == "cs"   }.map(\.name))

let tookBoth = mathTakers.intersection(csTakers)   // in BOTH sets
let csOnly   = csTakers.subtracting(mathTakers)     // in cs but NOT math

// ----------------------------------------------------------------------------
// 5. Ranges: half-open (..<) and closed (...).
// ----------------------------------------------------------------------------

let topIndexes = 0..<min(2, csScores.count)
// inferred: Range<Int>. Half-open: 0 and 1, but NOT 2.

let topTwoCs = csScores[topIndexes].map { $0 }
// slice the sorted cs scores by range.

func grade(for score: Int) -> String {
    switch score {
    case 90...100: return "A"     // closed range includes 100
    case 80..<90:  return "B"     // half-open: 80 up to but not including 90
    case 70..<80:  return "C"
    default:       return "F"
    }
}

// ----------------------------------------------------------------------------
// 6. Tuples: return more than one value, destructure on the way out.
// ----------------------------------------------------------------------------

func summarize(_ scores: [Int]) -> (min: Int, max: Int, mean: Double) {
    guard !scores.isEmpty else { return (0, 0, 0) }
    let lo = scores.min() ?? 0     // Int? -> Int via ??
    let hi = scores.max() ?? 0
    let mean = Double(scores.reduce(0, +)) / Double(scores.count)
    return (min: lo, max: hi, mean: mean)
}

let (lo, hi, mean) = summarize(records.map(\.score))   // destructuring a tuple

// ----------------------------------------------------------------------------
// Driver — prints the expected output
// ----------------------------------------------------------------------------

print("== 1. parsed records ==")
print("count: \(records.count)")

print("== 2. arrays ==")
print("cs scores (desc): \(csScores)")
print("total: \(total)  average: \(String(format: "%.2f", average))")

print("== 3. dictionaries ==")
for subject in scoresBySubject.keys.sorted() {
    let scores = (scoresBySubject[subject] ?? []).sorted()
    print("\(subject): scores=\(scores) best=\(bestBySubject[subject] ?? 0)")
}

print("== 4. sets ==")
print("distinct names: \(names.sorted())")
print("subjects: \(subjects.sorted())")
print("took both: \(tookBoth.sorted())")
print("cs only: \(csOnly.sorted())")

print("== 5. ranges ==")
print("top two cs: \(topTwoCs)")
print("grade(95)=\(grade(for: 95)) grade(85)=\(grade(for: 85)) grade(72)=\(grade(for: 72)) grade(50)=\(grade(for: 50))")

print("== 6. tuples ==")
print("all scores -> min=\(lo) max=\(hi) mean=\(String(format: "%.2f", mean))")

// ----------------------------------------------------------------------------
// YOUR TURN
// ----------------------------------------------------------------------------
//
// Add a function `subjectsPassedByEveryone(_:)` that returns the Set of
// subjects in which EVERY distinct name scored at least 80. Use Set algebra.
//
//   For this dataset:
//     - cs:   grace(85), edsger(95), ada(70), linus(88)
//             ada scored 70 in cs, so cs is NOT passed by everyone who took it.
//     - math: ada(90), grace(100) — both >= 80, so math IS passed by everyone who took it.
//   Expected result: ["math"]
//
// A reference solution is in the hints. Implement it, then uncomment the print.

func subjectsPassedByEveryone(_ records: [Record]) -> Set<String> {
    var result: Set<String> = []
    let allSubjects = Set(records.map(\.subject))
    for subject in allSubjects {
        let scoresInSubject = records.filter { $0.subject == subject }.map(\.score)
        if scoresInSubject.allSatisfy({ $0 >= 80 }) {
            result.insert(subject)
        }
    }
    return result
}

print("== YOUR TURN ==")
print("passed by everyone: \(subjectsPassedByEveryone(records).sorted())")

// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// == 1. parsed records ==
// count: 6
// == 2. arrays ==
// cs scores (desc): [95, 88, 85, 70]
// total: 528  average: 88.00
// == 3. dictionaries ==
// cs: scores=[70, 85, 88, 95] best=95
// math: scores=[90, 100] best=100
// == 4. sets ==
// distinct names: ["ada", "edsger", "grace", "linus"]
// subjects: ["cs", "math"]
// took both: ["ada", "grace"]
// cs only: ["edsger", "linus"]
// == 5. ranges ==
// top two cs: [95, 88]
// grade(95)=A grade(85)=B grade(72)=C grade(50)=F
// == 6. tuples ==
// all scores -> min=70 max=100 mean=88.00
// == YOUR TURN ==
// passed by everyone: ["math"]
//
// ----------------------------------------------------------------------------
// ACCEPTANCE CRITERIA
// ----------------------------------------------------------------------------
//
//   [ ] `swift exercise-03-collections.swift` runs with no errors or warnings.
//   [ ] Output matches the expected output above.
//   [ ] You can explain, for at least three lines, what type inference deduced
//       and why (the `// inferred:` comments are your study guide).
//   [ ] Your `subjectsPassedByEveryone` uses a Set and `allSatisfy`.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck >15 min)
// ----------------------------------------------------------------------------
//
// One-pipeline reference solution using Dictionary(grouping:by:):
//
//   func subjectsPassedByEveryone(_ records: [Record]) -> Set<String> {
//       let grouped = Dictionary(grouping: records, by: { $0.subject })
//       let passing = grouped.filter { _, group in group.allSatisfy { $0.score >= 80 } }
//       return Set(passing.keys)
//   }
//
// Note `["ada"]` appears in "took both" because ada has both a math and a cs
// record. Set intersection finds names present in BOTH the math-takers and
// cs-takers sets.
//
// ----------------------------------------------------------------------------
