// Exercise 3 — Bounded concurrency and back-pressure
//
// Goal: Cap a TaskGroup to a configurable maximum number of in-flight tasks
//       (back-pressure), and MEASURE how the peak in-flight count and total
//       wall-clock time change as you vary the cap. You will prove to yourself
//       that an unbounded group spawns everything at once, and that the
//       sliding-window pattern keeps in-flight work pinned at the cap.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
//   mkdir Backpressure && cd Backpressure
//   swift package init --type executable --name Backpressure
//   # Replace Sources/Backpressure/Backpressure.swift with THIS FILE.
//   swift run Backpressure 100 0          # 100 jobs, unbounded (0 = no cap)
//   swift run Backpressure 100 8          # 100 jobs, max 8 in flight
//
// THIS FILE IS COMPLETE AND RUNNABLE AS-IS. There are no TODOs to make it
// compile. Your job is to RUN it at several caps, READ the report, and answer
// the questions at the bottom. Then do the stretch, which DOES require edits.
//
// ACCEPTANCE CRITERIA
//
//   [ ] swift build: no warnings, no errors.
//   [ ] `swift run Backpressure 100 0` reports a peak in-flight of 100.
//   [ ] `swift run Backpressure 100 8` reports a peak in-flight of 8.
//   [ ] You can explain why the bounded run's peak never exceeds the cap.
//   [ ] You answered the three questions at the bottom in a comment or notes file.

import Foundation

// ----------------------------------------------------------------------------
// A thread-safe counter that tracks how many jobs are running RIGHT NOW and the
// high-water mark. We use an OSAllocatedUnfairLock-free approach via a simple
// actor-like serial wrapper built on a lock, because actors are Week 4.
// (A real codebase would make this an actor; here we keep it minimal and
//  @unchecked Sendable with explicit locking so the focus stays on the group.)
// ----------------------------------------------------------------------------
final class InFlightMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private var peak = 0

    func enter() {
        lock.lock()
        current += 1
        if current > peak { peak = current }
        lock.unlock()
    }

    func leave() {
        lock.lock()
        current -= 1
        lock.unlock()
    }

    var highWaterMark: Int {
        lock.lock(); defer { lock.unlock() }
        return peak
    }
}

// ----------------------------------------------------------------------------
// One unit of work. Increments the meter on entry, sleeps a little, decrements
// on exit. The sleep stands in for "I/O that holds a socket/FD for a while".
// ----------------------------------------------------------------------------
func job(_ id: Int, meter: InFlightMeter) async -> Int {
    meter.enter()
    defer { meter.leave() }
    // Vary the cost a little so completions interleave realistically.
    let ms = 20 + (id % 5) * 10
    try? await Task.sleep(for: .milliseconds(ms))
    return id
}

// ----------------------------------------------------------------------------
// UNBOUNDED: addTask for everything up front, THEN drain. This is the trap.
// All `count` jobs are in flight at once — peak in-flight == count.
// ----------------------------------------------------------------------------
func runUnbounded(count: Int, meter: InFlightMeter) async -> Int {
    await withTaskGroup(of: Int.self) { group in
        for i in 0..<count {
            group.addTask { await job(i, meter: meter) }   // ALL spawned immediately
        }
        var sum = 0
        for await r in group { sum += r }
        return sum
    }
}

// ----------------------------------------------------------------------------
// BOUNDED: the sliding-window pattern from Lecture 1, §8.
// Prime up to `maxConcurrent` jobs, then start a new one only as each finishes.
// Peak in-flight is pinned at the cap.
// ----------------------------------------------------------------------------
func runBounded(count: Int, maxConcurrent: Int, meter: InFlightMeter) async -> Int {
    await withTaskGroup(of: Int.self) { group in
        var index = 0
        var sum = 0

        let window = min(maxConcurrent, count)
        while index < window {
            let id = index
            group.addTask { await job(id, meter: meter) }
            index += 1
        }

        while let r = await group.next() {     // one finished
            sum += r
            if index < count {                 // top the window back up
                let id = index
                group.addTask { await job(id, meter: meter) }
                index += 1
            }
        }
        return sum
    }
}

@main
struct Backpressure {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        let count = Int(args.first ?? "100") ?? 100
        let cap = Int(args.dropFirst().first ?? "0") ?? 0   // 0 means unbounded

        let meter = InFlightMeter()
        let clock = ContinuousClock()
        let start = clock.now

        let sum: Int
        if cap <= 0 {
            sum = await runUnbounded(count: count, meter: meter)
        } else {
            sum = await runBounded(count: count, maxConcurrent: cap, meter: meter)
        }

        let elapsed = start.duration(to: clock.now)
        let mode = cap <= 0 ? "UNBOUNDED" : "bounded(\(cap))"
        print("""
        mode:            \(mode)
        jobs:            \(count)
        peak in-flight:  \(meter.highWaterMark)
        checksum (sum):  \(sum)   (expected \((0..<count).reduce(0, +)))
        wall clock:      \(elapsed)
        """)
    }
}

// ----------------------------------------------------------------------------
// EXPECTED OUTPUT (timings vary by machine)
// ----------------------------------------------------------------------------
//
//   $ swift run Backpressure 100 0
//   mode:            UNBOUNDED
//   jobs:            100
//   peak in-flight:  100
//   checksum (sum):  4950   (expected 4950)
//   wall clock:      0.0... seconds        ← everything ran at once
//
//   $ swift run Backpressure 100 8
//   mode:            bounded(8)
//   jobs:            100
//   peak in-flight:  8
//   checksum (sum):  4950   (expected 4950)
//   wall clock:      0.3... seconds        ← serialised into ~13 waves of 8
//
// The checksum proves both modes did the SAME work and lost nothing. The peak
// proves back-pressure works: bounded(8) never has more than 8 jobs in flight.
// The wall clock shows the trade-off: bounding trades latency for resource
// safety. The unbounded run is faster HERE only because Task.sleep holds no
// real resource. Replace `job` with a real HTTP HEAD request and the unbounded
// run will exhaust file descriptors at a few thousand jobs — which is exactly
// why the link-checker mini-project defaults to a cap of 16.
//
// ----------------------------------------------------------------------------
// QUESTIONS TO ANSWER (write your answers in notes, or a comment here)
// ----------------------------------------------------------------------------
//
//  Q1. Run `swift run Backpressure 1000 0` and `swift run Backpressure 1000 16`.
//      What is the peak in-flight for each? Why is the unbounded peak 1000?
//
//  Q2. The unbounded run is faster in wall-clock time here. Give a concrete
//      reason this would REVERSE if `job` made a real network request to a
//      server that rate-limits you (hint: think about timeouts and retries).
//
//  Q3. Why does `group.next()` (not `for await ... in group`) make the
//      sliding-window pattern possible? What does next() give you that the
//      for-await loop hides?
//
// ----------------------------------------------------------------------------
// STRETCH (requires edits)
// ----------------------------------------------------------------------------
//
//  S1. Add a third mode `bounded-async-let` that processes the jobs in fixed
//      chunks of `cap` using async let inside a loop over chunks. Compare its
//      peak and timing to the sliding window. (You'll find chunking has a
//      "convoy" problem: a chunk waits for its SLOWEST member before the next
//      chunk starts, so peak is right but throughput is worse than the window.)
//
//  S2. Make `job` occasionally "fail" (return -1 for ids divisible by 7) and
//      have the bounded runner count failures separately from the checksum.
//      Confirm one failure never aborts the batch — failure stays as data.
//
//  S3. Replace InFlightMeter's NSLock with an `actor` (peek ahead to Week 4).
//      Note how the call sites must become `await meter.enter()`. Discuss why
//      that changes the shape of `job`.
//
// ----------------------------------------------------------------------------
