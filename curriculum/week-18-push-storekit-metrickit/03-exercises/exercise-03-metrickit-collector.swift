// Exercise 3 — A MetricKit collector that ships payloads to a backend
//
// Goal: Build the telemetry pipeline home. Register an MXMetricManagerSubscriber,
//       receive metric and diagnostic payloads, serialize each to its JSON
//       representation, and ship it to a backend endpoint. The OS delivers real
//       payloads on a device on a ~24h cadence, so the TEST drives the same
//       code path with a synthetic upload to prove the wiring and the
//       serialization, and the SUBSCRIBER is what you register on a real device.
//
// Estimated time: 40 minutes.
//
// HOW TO USE THIS FILE
//
// MetricKit (`MXMetricManager`) delivers payloads on a PHYSICAL DEVICE roughly
// once per 24 hours, when the app next launches. You cannot force a real payload
// in a test. So this exercise has two parts:
//
//   1. The COLLECTOR — `MetricsCollector` — which you register on a real device
//      via `MXMetricManager.shared.add(_:)`. On a device it eventually receives
//      `didReceive([MXMetricPayload])` / `didReceive([MXDiagnosticPayload])`.
//
//   2. The UPLOAD path — extracted so it's testable WITHOUT a real payload. The
//      `@Test` drives `upload(payloadJSON:)` with synthetic bytes against a mock
//      uploader, proving the serialize-and-ship wiring is correct.
//
// On a real device, you can also TRIGGER a diagnostic to verify end to end:
// run a debug build, use Xcode ▸ Debug ▸ Simulate ... or deliberately hang the
// main thread, then relaunch a day later and watch a payload arrive.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency warnings).
//   [ ] `MetricsCollector` conforms to MXMetricManagerSubscriber and registers.
//   [ ] The upload path serializes a payload's JSON and ships it; the test
//       proves it's called with the right bytes against a mock uploader.
//   [ ] You can explain the difference between an MXMetricPayload and an
//       MXDiagnosticPayload, and why MetricKit complements Instruments.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import MetricKit
import Testing

// ----------------------------------------------------------------------------
// The uploader is a protocol so the test can substitute a mock. The real one
// posts to your Vapor backend over the signed, pinned NotesClient from Week 17.
// ----------------------------------------------------------------------------

protocol PayloadUploader: Sendable {
    func upload(_ json: Data, kind: PayloadKind) async throws
}

enum PayloadKind: String, Sendable {
    case metric        // aggregated CPU/memory/disk/launch/hang/hitch histograms
    case diagnostic    // crashes, hangs, disk-write exceptions (with call stacks)
}

// ----------------------------------------------------------------------------
// The collector. On a device, the OS calls the didReceive(...) methods ~daily.
// We extract `handle(...)` so the serialize-and-ship logic is testable.
// ----------------------------------------------------------------------------

final class MetricsCollector: NSObject, MXMetricManagerSubscriber {
    private let uploader: any PayloadUploader

    init(uploader: any PayloadUploader) {
        self.uploader = uploader
        super.init()
    }

    /// Call at app launch. The OS then delivers payloads on its own schedule.
    func register() {
        MXMetricManager.shared.add(self)
    }

    func unregister() {
        MXMetricManager.shared.remove(self)
    }

    // Performance metrics — aggregated histograms across the last ~24h.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            handle(json: payload.jsonRepresentation(), kind: .metric)
        }
    }

    // Diagnostics — the high-value ones: crashes, hangs, disk-write exceptions.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            handle(json: payload.jsonRepresentation(), kind: .diagnostic)
        }
    }

    /// Testable seam: serialize-and-ship. Fire-and-forget; a failed upload must
    /// never crash the app (telemetry is best-effort, like push).
    func handle(json: Data, kind: PayloadKind) {
        let uploader = self.uploader
        Task {
            try? await uploader.upload(json, kind: kind)
        }
    }
}

// ----------------------------------------------------------------------------
// Tests — drive the upload path with synthetic payload bytes and a mock.
// ----------------------------------------------------------------------------

actor MockUploader: PayloadUploader {
    private(set) var uploads: [(json: Data, kind: PayloadKind)] = []

    func upload(_ json: Data, kind: PayloadKind) async throws {
        uploads.append((json, kind))
    }

    func count() -> Int { uploads.count }
    func last() -> (json: Data, kind: PayloadKind)? { uploads.last }
}

struct MetricsCollectorTests {

    @Test("A metric payload's JSON is shipped with the .metric kind")
    func shipsMetricPayload() async throws {
        let mock = MockUploader()
        let collector = MetricsCollector(uploader: mock)

        // Synthetic payload bytes stand in for MXMetricPayload.jsonRepresentation().
        let synthetic = Data(#"{"cpuMetrics":{"cumulativeCPUTime":"42 sec"}}"#.utf8)
        collector.handle(json: synthetic, kind: .metric)

        // handle(...) fires a detached Task; give it a moment to run.
        try await Task.sleep(for: .milliseconds(50))

        #expect(await mock.count() == 1)
        let last = try #require(await mock.last())
        #expect(last.kind == .metric)
        #expect(last.json == synthetic)
    }

    @Test("A diagnostic payload's JSON is shipped with the .diagnostic kind")
    func shipsDiagnosticPayload() async throws {
        let mock = MockUploader()
        let collector = MetricsCollector(uploader: mock)

        let synthetic = Data(#"{"crashDiagnostics":[{"signal":11}]}"#.utf8)
        collector.handle(json: synthetic, kind: .diagnostic)
        try await Task.sleep(for: .milliseconds(50))

        let last = try #require(await mock.last())
        #expect(last.kind == .diagnostic)
    }

    @Test("A failing uploader does not crash the collector")
    func uploadFailureIsSwallowed() async throws {
        struct ThrowingUploader: PayloadUploader {
            func upload(_ json: Data, kind: PayloadKind) async throws {
                throw URLError(.notConnectedToInternet)
            }
        }
        let collector = MetricsCollector(uploader: ThrowingUploader())
        // Should not throw or crash — telemetry is best-effort.
        collector.handle(json: Data("{}".utf8), kind: .metric)
        try await Task.sleep(for: .milliseconds(50))
        #expect(Bool(true))   // reaching here without a crash is the assertion
    }
}

// ----------------------------------------------------------------------------
// WHY this matters (write it in your own words first):
//
//   - MXMetricPayload is AGGREGATED histograms across ~24h (CPU, memory, disk,
//     launch time, hang time, hitch ratio, battery) — for spotting TRENDS and
//     regressions, not single events. MXDiagnosticPayload is per-incident
//     (crash/hang/disk-write) WITH a call-stack tree you symbolicate.
//
//   - MetricKit complements Instruments: Instruments profiles YOUR device in
//     your hands (Week 15); MetricKit reports from EVERYONE'S device in the
//     field. A hang you can't reproduce locally shows up in a hang diagnostic.
//
//   - Telemetry is best-effort, like push: a failed upload must never crash the
//     app. That's why `handle` is fire-and-forget with `try?`.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `MXMetricManager.shared.add(self)` registers; `remove(self)` unregisters.
//   Register once at launch (e.g. in your AppDelegate or App init).
//
// - You CANNOT force a real payload in a unit test — the OS schedules them. The
//   testable seam is `handle(json:kind:)`, which is why the flow is factored
//   that way. On a DEVICE, trigger a hang and relaunch a day later to see one.
//
// - `payload.jsonRepresentation()` returns `Data` ready to POST. There's also a
//   `dictionaryRepresentation()` if you want to inspect fields before upload.
//
// - `MXDiagnosticPayload` is iOS 14+; the `signpostMetrics` and newer hitch
//   metrics are later. Guard with availability if your floor is below the API.
//
// - The mock is an `actor` so its `uploads` array is concurrency-safe under
//   Swift 6. Don't make it a plain class with a mutable array — that's a data
//   race the compiler will (correctly) flag.
//
// ----------------------------------------------------------------------------
