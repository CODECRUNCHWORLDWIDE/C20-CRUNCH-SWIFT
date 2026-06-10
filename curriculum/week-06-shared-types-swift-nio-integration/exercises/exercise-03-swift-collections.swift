// Exercise 3 — Pick the right swift-collections structure on purpose
//
// Goal: Implement a small in-memory "recently viewed notes" feature THREE ways
//       and feel, in your own code, why the access pattern decides the data
//       structure. You will:
//
//         1. Build a bounded "most-recent-N" buffer with a Deque        (TODO 1)
//         2. Build an insertion-ordered id->title index with
//            OrderedDictionary                                          (TODO 2)
//         3. Build a "next note due for review" queue with a Heap       (TODO 3)
//
//       Then you write one paragraph per structure justifying the choice on
//       complexity and intent — the thing a senior engineer says in a review.
//
// Estimated time: 40 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Create an executable package:
//
//        mkdir collections-drill && cd collections-drill
//        swift package init --type executable --name collections-drill
//
//   2. Replace Package.swift with the manifest in HINT 0 below (it adds the
//      swift-collections dependency).
//
//   3. Replace Sources/collections-drill/main.swift with THIS FILE.
//
//   4. Fill in the three TODOs. Run with:
//
//        swift run collections-drill
//
// ACCEPTANCE CRITERIA
//
//   [ ] RecentBuffer drops from the FRONT when it exceeds its cap, using a
//       Deque, and stays O(1) at both ends. No Array.removeFirst().
//   [ ] TitleIndex iterates in INSERTION order, deterministically, with O(1)
//       lookup by id, using OrderedDictionary.
//   [ ] ReviewQueue always pops the EARLIEST-due note using a Heap, O(log n)
//       per insert and O(1) to peek the next-due item.
//   [ ] The program prints the expected output at the bottom of this file.
//   [ ] `swift build` succeeds with 0 warnings, 0 errors under Swift 6 mode.
//   [ ] You wrote the three justification paragraphs in results-ex03.md.
//
// Inline hints at the bottom of the file. Don't peek for 15 minutes.

import DequeModule
import HeapModule
import OrderedCollections

// ----------------------------------------------------------------------------
// A tiny note stand-in. (In the real workspace you'd import NotesCore.Note;
// here we keep the exercise self-contained so it runs without the server.)
// ----------------------------------------------------------------------------

struct Note: Hashable {
    let id: Int
    let title: String
}

// ----------------------------------------------------------------------------
// 1. RecentBuffer — a bounded "most recent N" buffer.
//
//    Access pattern: push new items at the back; when over capacity, drop the
//    OLDEST item from the front. Both ends are hot. Array.removeFirst() is O(n)
//    because it shifts every remaining element; Deque is O(1) at both ends.
// ----------------------------------------------------------------------------

struct RecentBuffer {
    private var items: Deque<Note> = []
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
    }

    /// Record that `note` was just viewed. If the buffer is over capacity after
    /// appending, drop the oldest entry from the front.
    mutating func record(_ note: Note) {
        // TODO 1 — append `note` at the back of `items`; if items.count exceeds
        // `capacity`, removeFirst() (the OLDEST). Both operations are O(1) on a
        // Deque. Do NOT use an Array here.
        fatalError("TODO 1 not implemented")
    }

    /// The buffered notes, oldest first.
    var oldestFirst: [Note] { Array(items) }

    /// The buffered notes, newest first.
    var newestFirst: [Note] { Array(items.reversed()) }
}

// ----------------------------------------------------------------------------
// 2. TitleIndex — an insertion-ordered id -> title index.
//
//    Access pattern: O(1) lookup of a title by note id, AND deterministic
//    iteration in the order entries were first inserted (for rendering a
//    stable list). A plain Dictionary gives O(1) lookup but random order; an
//    Array of pairs gives order but O(n) lookup. OrderedDictionary gives both.
// ----------------------------------------------------------------------------

struct TitleIndex {
    private var byID: OrderedDictionary<Int, String> = [:]

    /// Insert or update the title for `note`. First insertion fixes its order.
    mutating func upsert(_ note: Note) {
        // TODO 2 — set byID[note.id] = note.title. On an OrderedDictionary this
        // is O(1) and preserves the insertion order of keys: re-assigning an
        // existing key updates the value WITHOUT changing its position.
        fatalError("TODO 2 not implemented")
    }

    /// O(1) lookup of a title by id.
    func title(for id: Int) -> String? { byID[id] }

    /// Titles in insertion order — deterministic across runs.
    var titlesInOrder: [String] { Array(byID.values) }
}

// ----------------------------------------------------------------------------
// 3. ReviewQueue — "which note is due for review next?"
//
//    Access pattern: insert notes with a due-day priority; repeatedly extract
//    the EARLIEST-due one. A sorted Array costs O(n log n) to re-sort on every
//    insert (or O(n) to insert in order); a Heap is O(log n) per insert and
//    O(1) to peek the minimum, O(log n) to pop it.
// ----------------------------------------------------------------------------

/// A note paired with the day it is next due. Comparable by dueDay so the Heap
/// orders by "soonest due."
struct DueNote: Comparable {
    let dueDay: Int
    let note: Note

    static func < (lhs: DueNote, rhs: DueNote) -> Bool { lhs.dueDay < rhs.dueDay }
}

struct ReviewQueue {
    private var heap: Heap<DueNote> = []

    /// Schedule `note` to be reviewed on `dueDay`.
    mutating func schedule(_ note: Note, dueDay: Int) {
        // TODO 3 — insert DueNote(dueDay: dueDay, note: note) into `heap`.
        // Heap.insert is O(log n).
        fatalError("TODO 3 not implemented")
    }

    /// The next note due (smallest dueDay) without removing it. O(1).
    var next: DueNote? { heap.min }

    /// Remove and return the next note due. O(log n).
    mutating func popNext() -> DueNote? { heap.popMin() }

    var isEmpty: Bool { heap.isEmpty }
}

// ----------------------------------------------------------------------------
// Driver
// ----------------------------------------------------------------------------

let notes = [
    Note(id: 1, title: "Buy oat milk"),
    Note(id: 2, title: "Call the dentist"),
    Note(id: 3, title: "Renew passport"),
    Note(id: 4, title: "Water the plants"),
]

print("== RecentBuffer (cap 3) ==")
var recent = RecentBuffer(capacity: 3)
for n in notes { recent.record(n) }          // 4 viewed, cap 3 -> oldest dropped
print("newest first:", recent.newestFirst.map(\.title))

print("\n== TitleIndex (insertion order) ==")
var index = TitleIndex()
index.upsert(notes[2])                        // Renew passport  (inserted first)
index.upsert(notes[0])                        // Buy oat milk
index.upsert(notes[1])                        // Call the dentist
index.upsert(Note(id: 3, title: "Renew passport (expedited)")) // update id 3 in place
print("title for id 1:", index.title(for: 1) ?? "(none)")
print("titles in order:", index.titlesInOrder)

print("\n== ReviewQueue (earliest due first) ==")
var queue = ReviewQueue()
queue.schedule(notes[0], dueDay: 5)
queue.schedule(notes[1], dueDay: 1)
queue.schedule(notes[2], dueDay: 9)
queue.schedule(notes[3], dueDay: 3)
print("next due:", queue.next.map { "\($0.note.title) (day \($0.dueDay))" } ?? "(none)")
var order: [String] = []
while let due = queue.popNext() { order.append("\(due.note.title) (day \(due.dueDay))") }
print("drained in due order:")
for line in order { print("  \(line)") }

// ----------------------------------------------------------------------------
// EXPECTED OUTPUT
// ----------------------------------------------------------------------------
//
// == RecentBuffer (cap 3) ==
// newest first: ["Water the plants", "Renew passport", "Call the dentist"]
//
// == TitleIndex (insertion order) ==
// title for id 1: Buy oat milk
// titles in order: ["Renew passport (expedited)", "Buy oat milk", "Call the dentist"]
//
// == ReviewQueue (earliest due first) ==
// next due: Call the dentist (day 1)
// drained in due order:
//   Call the dentist (day 1)
//   Water the plants (day 3)
//   Buy oat milk (day 5)
//   Renew passport (day 9)
//
// ----------------------------------------------------------------------------
// HINTS — peek only if stuck > 15 minutes.
// ----------------------------------------------------------------------------
//
// HINT 0 — Package.swift:
//
//   // swift-tools-version:6.0
//   import PackageDescription
//
//   let package = Package(
//       name: "collections-drill",
//       platforms: [.macOS(.v14)],
//       dependencies: [
//           .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0")
//       ],
//       targets: [
//           .executableTarget(
//               name: "collections-drill",
//               dependencies: [
//                   .product(name: "DequeModule", package: "swift-collections"),
//                   .product(name: "HeapModule", package: "swift-collections"),
//                   .product(name: "OrderedCollections", package: "swift-collections")
//               ],
//               swiftSettings: [.swiftLanguageMode(.v6)]
//           )
//       ]
//   )
//
// HINT 1 — TODO 1 (RecentBuffer.record):
//
//   items.append(note)
//   if items.count > capacity { items.removeFirst() }
//
// HINT 2 — TODO 2 (TitleIndex.upsert):
//
//   byID[note.id] = note.title
//
// HINT 3 — TODO 3 (ReviewQueue.schedule):
//
//   heap.insert(DueNote(dueDay: dueDay, note: note))
//
// ----------------------------------------------------------------------------
// JUSTIFICATION — write these in results-ex03.md (one paragraph each):
//
//   1. Deque vs Array for RecentBuffer: name the operation whose complexity
//      differs, give both Big-O values, and say at what N the difference
//      starts to matter in practice.
//   2. OrderedDictionary vs (Dictionary + [Int]) for TitleIndex: what bug does
//      the single structure prevent that the two-structure version invites?
//   3. Heap vs sorted Array for ReviewQueue: give the per-insert and per-peek
//      complexity of each, and name one workload where the sorted Array would
//      actually be the better choice.
// ----------------------------------------------------------------------------
