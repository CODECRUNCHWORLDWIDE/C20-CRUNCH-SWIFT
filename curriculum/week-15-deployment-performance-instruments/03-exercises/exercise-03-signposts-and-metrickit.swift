// Exercise 3 — Signposts in the trace, and MetricKit field telemetry
//
// Goal: Two complementary instruments for "is my app fast in the real world."
//       (1) Wrap an operation in an OSSignposter interval so it shows up as a
//           NAMED region in any Instruments trace, lined up against the system
//           tracks — the bridge between "my code" and "the profiler's view."
//       (2) Wire an MXMetricManagerSubscriber that receives the OS's DAILY
//           metric and diagnostic payloads (hangs, launches, crashes) — the
//           field telemetry that tells you about devices you don't own.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into a SwiftUI app target (iOS 17+/macOS 14+). The signpost part is
// visible immediately in an Instruments trace. The MetricKit part is DELAYED:
// payloads arrive ONCE PER DAY, batched, on a subsequent launch — you won't see
// one the moment you register. That delay is the delivery model, not a bug.
//
//   1. Add this file; call `MetricsCollector.shared.start()` in your App init.
//   2. Wrap an operation in `signposted("name") { ... }` and profile (Cmd-I):
//      the interval appears in the os_signpost track.
//   3. To see a MetricKit payload sooner during development, use Xcode's
//      Debug ▸ Simulate MetricKit Payloads (or wait ~24h on a real device).
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] A `signposted` interval appears as a named region in an Instruments
//       trace (os_signpost / Points of Interest track).
//   [ ] `MetricsCollector` conforms to MXMetricManagerSubscriber and logs both
//       MXMetricPayload and MXDiagnosticPayload.
//   [ ] You can explain why MetricKit payloads arrive once per day, batched.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import SwiftUI
import OSLog
import MetricKit

// ----------------------------------------------------------------------------
// PART 1 — Signposts: put YOUR operations in the trace.
// ----------------------------------------------------------------------------

let perfLog = Logger(subsystem: "com.crunch.notes", category: "perf")
let signposter = OSSignposter(logger: perfLog)

/// Wrap any block so it appears as a NAMED interval in Instruments, correlated
/// with the Time Profiler / Hangs / Hitches tracks. Use a StaticString name so
/// the signpost subsystem can record it cheaply.
@discardableResult
func signposted<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
    let state = signposter.beginInterval(name)
    defer { signposter.endInterval(name, state) }
    return try work()
}

/// Async variant for awaited work.
@discardableResult
func signposted<T>(_ name: StaticString, _ work: () async throws -> T) async rethrows -> T {
    let state = signposter.beginInterval(name)
    defer { signposter.endInterval(name, state) }
    return try await work()
}

// ----------------------------------------------------------------------------
// PART 2 — MetricKit: field telemetry from real users' devices.
// ----------------------------------------------------------------------------

let metricLog = Logger(subsystem: "com.crunch.notes", category: "metrickit")

final class MetricsCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsCollector()

    /// Register early — in App.init or applicationDidFinishLaunching.
    func start() {
        MXMetricManager.shared.add(self)
        metricLog.log("MetricKit subscriber registered")
    }

    // Daily AGGREGATED metrics: launch time, hang rate, memory, disk, scroll hitches.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            metricLog.log("metric payload: \(payload.jsonRepresentation().count) bytes")

            if let launch = payload.applicationLaunchMetrics {
                metricLog.log("time-to-first-draw histogram present: \(launch.histogrammedTimeToFirstDraw.totalBucketCount) buckets")
            }
            if let responsiveness = payload.applicationResponsivenessMetrics {
                metricLog.log("hang-time histogram present: \(responsiveness.histogrammedApplicationHangTime.totalBucketCount) buckets")
            }
            if let memory = payload.memoryMetrics {
                metricLog.log("peak memory: \(memory.peakMemoryUsage.description)")
            }
            // In production: POST payload.jsonRepresentation() to your backend and
            // aggregate across users into a dashboard.
        }
    }

    // DIAGNOSTICS: crashes, hangs, CPU exceptions, disk-write exceptions, w/ stacks.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            metricLog.log("diagnostic payload: \(payload.jsonRepresentation().count) bytes")

            for crash in payload.crashDiagnostics ?? [] {
                metricLog.error("crash diagnostic — termination: \(crash.terminationReason ?? "unknown")")
            }
            for hang in payload.hangDiagnostics ?? [] {
                metricLog.error("hang diagnostic — duration: \(hang.hangDuration.description)")
            }
            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                metricLog.error("cpu-exception diagnostic — total CPU: \(cpu.totalCPUTime.description)")
            }
        }
    }
}

// ----------------------------------------------------------------------------
// A view that exercises a signposted operation so you have something to profile.
// ----------------------------------------------------------------------------

struct SignpostDemoView: View {
    @State private var sum = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Sum: \(sum)").font(.system(.title2, design: .monospaced))
            Button("Run signposted work") {
                // This whole block shows up as a "compute-sum" interval in the trace.
                sum = signposted("compute-sum") {
                    (0..<5_000_000).reduce(0) { $0 &+ ($1 & 0xFF) }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { MetricsCollector.shared.start() }
    }
}

#Preview { SignpostDemoView() }

// ----------------------------------------------------------------------------
// WHY MetricKit payloads arrive once per day, batched (write before reading):
//
//   MetricKit is designed for LOW-OVERHEAD field telemetry, not live profiling.
//   The OS collects metrics and diagnostics in the background and delivers them
//   in a single daily batch on a subsequent app launch, so collecting them costs
//   the user almost no battery or CPU. You get yesterday's aggregate, not a live
//   stream — which is exactly right for "what's my real users' hang rate," and
//   why you use Instruments (live) for bugs you can reproduce and MetricKit
//   (daily, aggregate) for the ones you can't.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Signpost intervals show up in the "os_signpost" / "Points of Interest"
//   track in Instruments. Add that instrument to your trace (or use a template
//   that includes it) and you'll see "compute-sum" as a labeled region.
//
// - The signpost NAME must be a StaticString (a compile-time literal), not a
//   String variable — that's what lets the subsystem record it without
//   allocating. Use `"compute-sum"` literally, not a computed name.
//
// - You will NOT see a MetricKit payload immediately. Use Xcode's
//   Debug ▸ Simulate MetricKit Payloads while the app runs on a device to get a
//   synthetic one, or wait ~24h. Registering the subscriber is all you control;
//   delivery is the OS's call.
//
// - MetricKit needs a real device (or the simulate menu); the metrics are about
//   device behavior the Simulator can't faithfully produce.
//
// - `jsonRepresentation()` is what you'd actually upload to a backend. Logging
//   its byte count here just proves you received a non-empty payload.
//
// ----------------------------------------------------------------------------
