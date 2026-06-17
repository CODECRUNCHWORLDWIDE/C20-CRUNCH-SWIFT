# Challenge 1 — Plant a SwiftData footgun, then refactor it (with numbers)

**Time.** 60–120 minutes.
**Deliverable.** A short report (`PERF.md`) with two timings and one Instruments screenshot, plus the refactored code, committed to your Week 10 repo.

## The premise

Every senior engineer has, at least once, shipped the "fetch everything, then filter in Swift" footgun. It works perfectly in the demo. Then the user accumulates real data and the search field starts dropping frames or the app gets a memory warning. The skill this challenge builds is not "know the footgun exists" — it's **plant it, feel it, measure it, fix it, and prove the fix with a number.** A fix you can't quantify is a guess.

You will build a search over a large notes store the *wrong* way, measure it, then rewrite it the right way and measure again. The grading is the gap between the two numbers and your explanation of it.

## What to build

Start from your Hello, Notes app (or the `Scratch` app from exercise 1 — either works). The model needs enough text to make a search meaningful:

```swift
@Model
final class Note {
    var title: String
    var body: String
    var topic: String
    var createdAt: Date

    init(title: String, body: String, topic: String, createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.topic = topic
        self.createdAt = createdAt
    }
}
```

### Step 1 — Seed a large store

Write a one-shot seeder (a button, or a debug menu item) that inserts **50,000+** notes if the store is empty, with realistic text so a substring search has work to do. Insert in batches and save once at the end — don't save per row, that's a different footgun.

```swift
func seedIfEmpty(_ context: ModelContext) throws {
    guard try context.fetchCount(FetchDescriptor<Note>()) == 0 else { return }
    let topics = ["swift", "kotlin", "rust", "go", "python", "vapor"]
    for i in 0..<50_000 {
        context.insert(Note(
            title: "Note number \(i)",
            body: "This note is about \(topics[i % topics.count]) and item \(i). " +
                  "Lorem ipsum dolor sit amet, persistence edition.",
            topic: topics[i % topics.count],
            createdAt: Date(timeIntervalSince1970: TimeInterval(i))
        ))
    }
    try context.save()
}
```

### Step 2 — Plant the footgun (the WRONG search)

Implement a search that fetches **all** notes and filters the array in Swift. This is the code under test, the thing you will delete in step 4. Wrap it in a timing harness so every keystroke produces a number in the log.

```swift
import OSLog

let perfLog = Logger(subsystem: "com.crunch.notes", category: "perf")
let signposter = OSSignposter(logger: perfLog)

func searchNaive(_ query: String, in context: ModelContext) -> [Note] {
    let state = signposter.beginInterval("search.naive")
    let clock = ContinuousClock()
    let start = clock.now
    defer {
        signposter.endInterval("search.naive", state)
        perfLog.log("search.naive('\(query, privacy: .public)') took \(clock.now - start)")
    }
    let all = (try? context.fetch(FetchDescriptor<Note>())) ?? []   // <- the footgun: fetch everything
    return all.filter {
        $0.title.localizedStandardContains(query) ||
        $0.body.localizedStandardContains(query)
    }
}
```

Run it. Type a query. Read the log. On 50k rows this is typically tens to hundreds of milliseconds and allocates the entire table. Record the number.

### Step 3 — Measure it properly in Instruments

Profile the app (Xcode ▸ Product ▸ Profile, or Cmd-I) and choose the **SwiftData** (or **Core Data**) template. Trigger a few searches. You should see:

- A single large `SELECT ... FROM ZNOTE` with no `WHERE`, fetching every row.
- Your `search.naive` signpost interval spanning that fetch plus the in-memory filter.
- A spike in allocations / object materialisation.

Screenshot the trace. This is your "before" evidence.

### Step 4 — Refactor to a `#Predicate` (the RIGHT search)

Push the filtering into SQLite. Same signature, same answer, vastly less work:

```swift
func searchPredicated(_ query: String, in context: ModelContext) -> [Note] {
    let state = signposter.beginInterval("search.predicated")
    let clock = ContinuousClock()
    let start = clock.now
    defer {
        signposter.endInterval("search.predicated", state)
        perfLog.log("search.predicated('\(query, privacy: .public)') took \(clock.now - start)")
    }
    let descriptor = FetchDescriptor<Note>(
        predicate: #Predicate { note in
            note.title.localizedStandardContains(query) ||
            note.body.localizedStandardContains(query)
        },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
}
```

Run it. Same query. Read the log. Record the new number. Profile again — the SQL trace now shows a `WHERE` clause and only the matching rows materialise.

### Step 5 (optional, for the stretch) — add an index

For an exact-match filter (e.g. searching by `topic`), declare a `#Index` (iOS 18+) and measure a third time:

```swift
@Model
final class Note {
    #Index<Note>([\.topic], [\.createdAt])   // composite index for topic filter + createdAt sort
    // ...properties as above...
}
```

Substring search (`localizedStandardContains`) can't use a B-tree index, so the index won't speed *that* up — but an exact `topic == "swift"` filter with a `createdAt` sort can. Measure both the substring and the exact-match cases and explain why the index helped one and not the other. That explanation is worth more than the timing itself.

## Acceptance criteria

- [ ] The store is seeded with **≥ 50,000** notes.
- [ ] `searchNaive` and `searchPredicated` both exist, return the **same rows** for the same query (assert this — a faster wrong answer is worthless), and are both timed.
- [ ] `PERF.md` records: the naive timing, the predicated timing, the speedup factor, and the machine/Simulator you measured on.
- [ ] One Instruments screenshot of the "before" trace showing the full-table fetch, and one of the "after" trace showing the `WHERE`-clause fetch.
- [ ] A 3–5 sentence explanation of **why** the predicate version wins (in-SQLite filtering, fewer rows materialised across the faulting layer) — in your own words, not copied from the lecture.
- [ ] (Stretch) An `#Index` added, measured, and an explanation of why it helps exact-match but not substring search.
- [ ] Build with **0 warnings**.

## What "great" looks like

A weak submission says "the predicate one was faster." A great submission says:

> On a 50,000-row store on an M2 Air iOS 18 Simulator, `search.naive` averaged 142 ms and materialised all 50,000 `Note` objects (peak allocation +38 MB in the trace). `search.predicated` averaged 1.8 ms and materialised only the 8,333 matching rows — a ~79× speedup. The naive version's cost is dominated by faulting every row across the Core Data layer to keep ~17% of them; the predicate moves the filter into SQLite's `WHERE` clause so only matching rows ever cross into Swift objects. The `#Index` on `topic` cut the exact-match `topic == "swift"` fetch from 0.9 ms to 0.2 ms, but did nothing for the substring search, because `localizedStandardContains` is a full scan that a B-tree index can't accelerate.

Quantified, explained, and honest about what the index did *not* do. That's the senior-engineer answer.

## Where this reappears

The "measure, don't guess" instinct and the `OSSignposter`/Instruments workflow are exactly what Phase III's performance week (Instruments: Time Profiler, Hangs, Allocations) builds on. The footgun you fixed here is the same shape as the main-thread-fetch hitch you'll diagnose then — just with a flame graph instead of a log line.
