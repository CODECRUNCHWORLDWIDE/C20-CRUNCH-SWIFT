// Exercise 2 — Cooperative cancellation through a task tree
//
// Goal: Implement cooperative cancellation with withTaskCancellationHandler and
//       PROVE it propagates from a parent task down through two levels of
//       children. You will see the onCancel handler fire the instant the root
//       is cancelled, and watch every leaf wind down and report cleanly.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
//   mkdir CancelDrill && cd CancelDrill
//   swift package init --type executable --name CancelDrill
//   # Replace Sources/CancelDrill/CancelDrill.swift with the contents of THIS FILE.
//   swift run
//
// If your template uses a top-level main.swift instead of an @main struct,
// rename the file to main.swift and delete the `@main` line + the struct wrapper
// (move main()'s body to the top level).
//
// WHAT THIS FILE ALREADY DOES (read it, then do the TODOs):
//   - Builds a two-level task tree:
//         root  ──>  3 "regions"  ──each──>  4 "workers"
//   - Each worker simulates work with a cancellable sleep.
//   - A timer cancels the root after 400 ms, mid-flight.
//   - You implement the cancellation handler and the cooperative checks so the
//     whole tree drains and reports, with NO leaked tasks and NO hang.
//
// ACCEPTANCE CRITERIA
//
//   [ ] swift build: no warnings, no errors.
//   [ ] On a normal (uninterrupted) run, all 12 workers print "done".
//   [ ] When cancelled at 400 ms, you see "cancellation observed" from the
//       handler, and the in-flight workers print "cancelled (cleaned up)".
//   [ ] The program EXITS promptly after cancellation — it does not hang.
//   [ ] No "continuation misuse" or "leaked task" crash.
//
// The TODOs are marked below. Hints are at the very bottom — don't peek for 15 min.

import Foundation

// A Sendable struct so it can cross task boundaries safely (Week 4 makes this
// rule strict; this week we stay safe by passing value types).
struct WorkOutcome: Sendable {
    let region: Int
    let worker: Int
    let cancelled: Bool
}

// ----------------------------------------------------------------------------
// A simulated resource that must be released on cancellation.
// In the real link-checker this is an in-flight URLSessionTask we must cancel.
// ----------------------------------------------------------------------------
final class FakeConnection: @unchecked Sendable {
    let region: Int
    let worker: Int
    init(region: Int, worker: Int) {
        self.region = region
        self.worker = worker
    }
    func close() {
        // Stand-in for "cancel the in-flight network request / close the socket".
        FileHandle.standardError.write(
            Data("    [conn r\(region) w\(worker)] closed by onCancel\n".utf8))
    }
}

// ----------------------------------------------------------------------------
// One leaf worker. This is where you implement cooperative cancellation.
// ----------------------------------------------------------------------------
func runWorker(region: Int, worker: Int) async -> WorkOutcome {
    let connection = FakeConnection(region: region, worker: worker)

    // TODO 1:
    //   Wrap the "do the work" body in withTaskCancellationHandler.
    //   - In `operation`, sleep for 1 second with a CANCELLABLE sleep, then,
    //     if not cancelled, return a non-cancelled WorkOutcome and print
    //     "r{region} w{worker}: done".
    //   - If the sleep is interrupted by cancellation, print
    //     "r{region} w{worker}: cancelled (cleaned up)" and return a cancelled
    //     WorkOutcome.
    //   - In `onCancel`, call connection.close(). (This fires IMMEDIATELY on
    //     cancellation — keep it tiny; it only touches Sendable state.)
    //
    // Replace the line below with your implementation.
    _ = connection
    return WorkOutcome(region: region, worker: worker, cancelled: false)
}

// ----------------------------------------------------------------------------
// One region: spawns 4 workers as structured children and gathers them.
// ----------------------------------------------------------------------------
func runRegion(_ region: Int) async -> [WorkOutcome] {
    await withTaskGroup(of: WorkOutcome.self) { group in
        for worker in 0..<4 {
            // TODO 2:
            //   addTask a child that calls runWorker(region:worker:).
            //   (Children inherit cancellation from the group, which inherits
            //    it from the root — that's the propagation you're proving.)
            _ = worker
        }
        var outcomes: [WorkOutcome] = []
        for await outcome in group {
            outcomes.append(outcome)
        }
        return outcomes
    }
}

// ----------------------------------------------------------------------------
// The root work: 3 regions concurrently. This is the top of the tree.
// ----------------------------------------------------------------------------
func runAll() async -> [WorkOutcome] {
    await withTaskGroup(of: [WorkOutcome].self) { group in
        for region in 0..<3 {
            group.addTask { await runRegion(region) }
        }
        var all: [WorkOutcome] = []
        for await regionOutcomes in group {
            all.append(contentsOf: regionOutcomes)
        }
        return all
    }
}

@main
struct CancelDrill {
    static func main() async {
        // Cancel after 400 ms unless the run was launched with `nocancel`.
        let cancelAfter = CommandLine.arguments.contains("nocancel")
            ? nil : Duration.milliseconds(400)

        // The root structured work, held as an unstructured task so a timer
        // can cancel it. This is the bridge pattern from Lecture 2.
        let work = Task { await runAll() }

        if let cancelAfter {
            // A SEPARATE task that waits, then cancels the root. When the root
            // is cancelled, cancellation flows down through both task groups to
            // every worker — that is the propagation you are verifying.
            Task {
                try? await Task.sleep(for: cancelAfter)
                FileHandle.standardError.write(Data("\n[timer] cancellation observed — cancelling root\n".utf8))
                work.cancel()
            }
        }

        let outcomes = await work.value
        let done = outcomes.filter { !$0.cancelled }.count
        let cancelled = outcomes.filter { $0.cancelled }.count
        print("\nSummary: \(done) done, \(cancelled) cancelled, \(outcomes.count) total. No leaked tasks.")
    }
}

// ----------------------------------------------------------------------------
// EXPECTED OUTPUT
// ----------------------------------------------------------------------------
//
//  Uninterrupted (`swift run CancelDrill nocancel`):
//    r0 w0: done
//    r2 w3: done
//    ... (12 lines total, in completion order) ...
//    Summary: 12 done, 0 cancelled, 12 total. No leaked tasks.
//
//  Cancelled (`swift run CancelDrill`, default):
//    [timer] cancellation observed — cancelling root
//        [conn r0 w0] closed by onCancel        (12 of these, on stderr)
//    r0 w0: cancelled (cleaned up)
//    ... (up to 12 "cancelled (cleaned up)" lines) ...
//    Summary: 0 done, 12 cancelled, 12 total. No leaked tasks.
//
//  The exact interleaving of stdout/stderr lines varies. What MUST hold:
//    - the program exits promptly (well under 1 second) when cancelled;
//    - every worker either reports "done" or "cancelled (cleaned up)";
//    - the count in the summary is always 12.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// TODO 1 — the worker body:
//
//   func runWorker(region: Int, worker: Int) async -> WorkOutcome {
//       let connection = FakeConnection(region: region, worker: worker)
//       return await withTaskCancellationHandler {
//           do {
//               try await Task.sleep(for: .seconds(1))   // cancellable
//               print("r\(region) w\(worker): done")
//               return WorkOutcome(region: region, worker: worker, cancelled: false)
//           } catch {
//               // Task.sleep throws CancellationError when the task is cancelled.
//               print("r\(region) w\(worker): cancelled (cleaned up)")
//               return WorkOutcome(region: region, worker: worker, cancelled: true)
//           }
//       } onCancel: {
//           connection.close()   // fires immediately, possibly on another thread
//       }
//   }
//
// TODO 2 — spawn the workers inside runRegion:
//
//   for worker in 0..<4 {
//       group.addTask { await runWorker(region: region, worker: worker) }
//   }
//
// WHY THIS WORKS:
//   work.cancel() cancels the root Task. The root is running runAll()'s
//   withTaskGroup; cancelling it cancels every child (each runRegion), which
//   cancels each of THEIR children (each runWorker). Inside runWorker, the
//   Task.sleep throws CancellationError, AND the onCancel handler fires
//   immediately to close the connection. The tree drains; main() returns from
//   `await work.value`. Cooperative cancellation, two levels deep.
//
// ----------------------------------------------------------------------------
