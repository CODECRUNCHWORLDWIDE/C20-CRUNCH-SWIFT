// Exercise 3 — A background refresh task done correctly
//
// Goal: Register and schedule a BGAppRefreshTask that pulls the latest notes and
//       reloads the widget, with a CORRECT expiration handler and a single
//       setTaskCompleted on every path, and detect Low Power Mode. This is the
//       contract people skip three steps of and then wonder why the task never
//       runs.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into your Hello, Notes app target. You must ALSO:
//   1. Add the task identifier to Info.plist under BGTaskSchedulerPermittedIdentifiers.
//   2. Enable Background Modes -> Background fetch + Background processing.
//   3. Register the handler EARLY (app init / didFinishLaunching).
// Then run in the Simulator and fire the task on demand with the LLDB trick below
// (you will not wait hours for the system to schedule it).
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (incl. Swift 6 strict-concurrency).
//   [ ] The identifier is listed in Info.plist; the handler is registered at launch.
//   [ ] The handler RE-SCHEDULES the next run, sets an expiration handler that
//       cancels cooperatively, does the work, and calls setTaskCompleted exactly once.
//   [ ] Low Power Mode is detected and logged.
//   [ ] You fired the task with the LLDB simulate-launch trick and saw it run.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import BackgroundTasks
import WidgetKit
import Foundation
import OSLog

private let bgLog = Logger(subsystem: "com.crunch.hellonotes", category: "background")

// ----------------------------------------------------------------------------
// Identifiers. These MUST appear verbatim in Info.plist's
// BGTaskSchedulerPermittedIdentifiers array, or register(...) fails.
// ----------------------------------------------------------------------------

enum BackgroundJobs {
    static let refreshID = "com.crunch.hellonotes.refresh"

    // Call ONCE, early in launch, BEFORE the launch sequence completes.
    static func registerHandlers() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) { task in
            // We registered this id as an app-refresh task, so the cast is sound.
            handleRefresh(task as! BGAppRefreshTask)
        }
        bgLog.log("Registered background handler for \(refreshID, privacy: .public)")
    }

    // Submit a request. earliestBeginDate is a FLOOR, not a promise.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)   // >= 15 min out
        do {
            try BGTaskScheduler.shared.submit(request)
            bgLog.log("Scheduled refresh; earliest \(request.earliestBeginDate?.description ?? "n/a", privacy: .public)")
        } catch {
            // Common: Background App Refresh disabled in Settings, or too many pending.
            bgLog.error("Could not schedule refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    // The handler. Note the FOUR obligations, in order.
    static func handleRefresh(_ task: BGAppRefreshTask) {
        // (1) Re-schedule the NEXT run first — background tasks do not auto-repeat.
        scheduleRefresh()

        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        bgLog.log("Refresh fired. lowPower=\(lowPower, privacy: .public)")

        // (2) Run the work in a Task so we can cancel it from the expiration handler.
        let work = Task {
            do {
                // Under Low Power Mode, do the minimum: skip heavy sync, just touch
                // what keeps the UI honest.
                try await NotesSync.pullLatest(minimal: lowPower)
                WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
                // (4) Complete exactly once, success path.
                task.setTaskCompleted(success: true)
                bgLog.log("Refresh completed successfully")
            } catch is CancellationError {
                // Expired mid-flight: mark as not-successful and stop.
                task.setTaskCompleted(success: false)
                bgLog.log("Refresh cancelled by expiration")
            } catch {
                task.setTaskCompleted(success: false)
                bgLog.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // (3) The expiration handler: iOS calls this when your time is up. Cancel
        // the work; the Task's CancellationError branch completes the task.
        task.expirationHandler = {
            bgLog.log("Expiration handler called — cancelling work")
            work.cancel()
        }
    }
}

// ----------------------------------------------------------------------------
// A stand-in for the real sync (Week 13 networking). `minimal` lets the caller
// shrink the work under Low Power Mode.
// ----------------------------------------------------------------------------

enum NotesSync {
    static func pullLatest(minimal: Bool) async throws {
        // Respect cancellation at await points so the expiration handler can stop us.
        try Task.checkCancellation()
        let count = minimal ? 5 : 50           // fetch fewer rows under Low Power Mode
        // ... fetch `count` latest notes from the Vapor backend and upsert into
        //     the shared App Group SwiftData store (Week 20) ...
        try await Task.sleep(for: .milliseconds(200))   // simulate network
        try Task.checkCancellation()
        bgLog.log("Pulled \(count) notes (minimal=\(minimal, privacy: .public))")
    }
}

// ----------------------------------------------------------------------------
// Wire-up: register at launch, schedule when the app backgrounds.
// In a SwiftUI app, register in the App's init and schedule in a scenePhase
// change, OR use the .backgroundTask(.appRefresh(_:)) scene modifier instead.
// ----------------------------------------------------------------------------
//
//   @main struct HelloNotesApp: App {
//       init() { BackgroundJobs.registerHandlers() }   // EARLY
//       @Environment(\.scenePhase) private var phase
//       var body: some Scene {
//           WindowGroup { RootView() }
//               .onChange(of: phase) { _, newPhase in
//                   if newPhase == .background { BackgroundJobs.scheduleRefresh() }
//               }
//       }
//   }

// ----------------------------------------------------------------------------
// Fire the task on demand (don't wait hours). Run the app, pause in the debugger
// AFTER registerHandlers() has run, and in the LLDB console:
//
//   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.crunch.hellonotes.refresh"]
//
// To test the expiration handler:
//
//   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.crunch.hellonotes.refresh"]
//
// ----------------------------------------------------------------------------
// WHY each contract step matters (write it before reading):
//
//   - id not in Info.plist  -> register() fails -> task NEVER runs.
//   - register too late     -> iOS won't deliver the task this launch.
//   - no re-schedule        -> the task runs ONCE and never again.
//   - no expiration handler -> overrun -> iOS KILLS the app and trusts you less.
//   - no setTaskCompleted   -> system thinks you're still running -> wasted budget,
//                              throttled future runs.
//   Background work is a contract; skip a clause and it silently breaks.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - register() throws / task never fires: the identifier string in code must
//   EXACTLY match the one in BGTaskSchedulerPermittedIdentifiers. A trailing
//   space or a typo means no task.
//
// - The simulate-launch LLDB command does nothing: you ran it before
//   registerHandlers() executed, or you're not on a real run (it works in the
//   Simulator and on device, after registration).
//
// - Task runs once then stops: you forgot to call scheduleRefresh() inside the
//   handler. Put it at the TOP of handleRefresh so it always re-arms.
//
// - App gets killed during the task: your work ignored cancellation. Add
//   try Task.checkCancellation() at await points and cancel from expirationHandler.
//
// - Strict-concurrency warning: keep the work in a structured Task; don't capture
//   non-Sendable app state. WidgetCenter and BGTaskScheduler calls are fine.
//
// ----------------------------------------------------------------------------
