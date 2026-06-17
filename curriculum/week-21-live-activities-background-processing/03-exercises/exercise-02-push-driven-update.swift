// Exercise 2 — Updating a Live Activity over APNs
//
// Goal: Take the activity from exercise 1 and make it update REMOTELY. Observe
//       the activity's pushToken, send it to your backend, and have the backend
//       push a `content-state` that updates the Lock Screen WHILE THE APP IS
//       TERMINATED. This is the week's actual promise: the backend moves the
//       pixels.
//
//       The lesson: the push `content-state` JSON must match your ContentState
//       EXACTLY (keys and Date encoding), or the decode fails and nothing changes.
//
// Estimated time: 55 minutes (the push path needs a physical device).
//
// HOW TO USE THIS FILE
//
// The client half (token observation + payload model) drops into your app target.
// The server half is shown as the Vapor sender SHAPE — adapt it into your Phase I
// Vapor backend's APNs sending (you minted the auth key in Week 18). You can also
// test the payload by hand with a JWT + curl against APNs before wiring Vapor.
//
//   1. Switch the activity to `pushType: .token` (exercise 1 used nil).
//   2. Observe `pushTokenUpdates`, send the hex token to the backend.
//   3. From the backend (or curl), push an `event: "update"` with content-state.
//   4. Force-quit the app; push again; watch the Lock Screen change with the app
//      NOT running.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (incl. Swift 6 strict-concurrency).
//   [ ] The activity is requested with pushType: .token.
//   [ ] pushTokenUpdates is observed and the token is sent to the backend, and
//       re-sent if it rotates.
//   [ ] The APNs `content-state` JSON matches ContentState exactly (Date as a
//       seconds-since-1970 number).
//   [ ] You demonstrate an update landing while the app is TERMINATED.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import ActivityKit
import Foundation

// ----------------------------------------------------------------------------
// CLIENT: start with a push token, observe and register it (and its rotations).
// ----------------------------------------------------------------------------

@MainActor
final class PushDrivenEditActivity {
    private var activity: Activity<NoteEditActivityAttributes>?

    func start(noteID: String, title: String, editor: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = NoteEditActivityAttributes(noteID: noteID, noteTitle: title)
        let state = NoteEditActivityAttributes.ContentState(
            editorName: editor, startedAt: .now, keystrokes: 0, isActive: true
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(1800)),
                pushType: .token   // <- the whole point: this activity is updatable via APNs
            )
            self.activity = activity
            observeToken(for: activity)
        } catch {
            print("start failed: \(error)")
        }
    }

    private func observeToken(for activity: Activity<NoteEditActivityAttributes>) {
        Task {
            // The token may arrive shortly after start AND may rotate later.
            // Observe the whole stream, not just the first value.
            for await tokenData in activity.pushTokenUpdates {
                let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                await NotesAPI.registerLiveActivityToken(hex, forNoteID: activity.attributes.noteID)
            }
        }
    }
}

// A stand-in for your real networking layer (Week 13). Sends the token to Vapor.
enum NotesAPI {
    static func registerLiveActivityToken(_ hexToken: String, forNoteID id: String) async {
        // POST to your Vapor backend: { "noteID": id, "activityToken": hexToken }
        // The server stores it keyed by note so it can push updates for that note.
        print("Registered Live Activity token \(hexToken.prefix(12))… for note \(id)")
    }
}

// ----------------------------------------------------------------------------
// PAYLOAD MODEL: the JSON the server sends MUST match ContentState exactly.
// This Codable mirror documents the contract; encode dates as seconds numbers.
// ----------------------------------------------------------------------------

struct LiveActivityUpdatePayload: Encodable {
    struct APS: Encodable {
        let timestamp: Int                 // server time, seconds since 1970
        let event: String                  // "update" or "end"
        let contentState: ContentStateDTO  // <- EXACTLY the keys of ContentState
        let staleDate: Int?
        let dismissalDate: Int?

        enum CodingKeys: String, CodingKey {
            case timestamp, event
            case contentState = "content-state"
            case staleDate = "stale-date"
            case dismissalDate = "dismissal-date"
        }
    }
    // Mirror of NoteEditActivityAttributes.ContentState. Date -> seconds number.
    struct ContentStateDTO: Encodable {
        let editorName: String
        let startedAt: Int       // seconds since 1970 (ActivityKit decodes Date from this)
        let keystrokes: Int
        let isActive: Bool
    }
    let aps: APS
}

// ----------------------------------------------------------------------------
// SERVER SHAPE: how the Vapor backend sends the update. (Pseudo-Vapor; adapt to
// APNSwift / vapor-apns in your backend. The headers and topic are the contract.)
// ----------------------------------------------------------------------------
//
//   POST https://api.push.apple.com/3/device/<activity-push-token-hex>
//   Headers:
//     apns-push-type: liveactivity
//     apns-topic:     com.crunch.hellonotes.push-type.liveactivity   <- the suffix is mandatory
//     apns-priority:  10
//     authorization:  bearer <JWT signed with your .p8 auth key>     <- Week 18
//   Body:
//     {
//       "aps": {
//         "timestamp": 1718900000,
//         "event": "update",
//         "content-state": { "editorName": "Sam", "startedAt": 718900000,
//                            "keystrokes": 142, "isActive": true },
//         "stale-date": 1718901800
//       }
//     }
//
// To END from the server, send event "end" with an optional dismissal-date:
//     { "aps": { "timestamp": ..., "event": "end",
//                "content-state": { ... "isActive": false },
//                "dismissal-date": 1718900600 } }

func buildUpdateBody(editor: String, started: Date, keystrokes: Int) throws -> Data {
    let payload = LiveActivityUpdatePayload(aps: .init(
        timestamp: Int(Date().timeIntervalSince1970),
        event: "update",
        contentState: .init(
            editorName: editor,
            startedAt: Int(started.timeIntervalSince1970),
            keystrokes: keystrokes,
            isActive: true
        ),
        staleDate: Int(Date().addingTimeInterval(1800).timeIntervalSince1970),
        dismissalDate: nil
    ))
    return try JSONEncoder().encode(payload)
}

// ----------------------------------------------------------------------------
// WHY the content-state must match exactly (write it before reading):
//
//   When the push lands, ActivityKit decodes `aps.content-state` into your
//   ContentState. If a key is missing or misnamed (editorName vs editor_name),
//   or a Date is a string instead of a seconds number, the decode FAILS and the
//   activity does not update — silently. There is no error on the Lock Screen.
//   So the server's JSON keys must be byte-identical to the ContentState's
//   properties, and dates must be numbers. Keep ContentState small, too: the
//   whole APNs payload is capped at 4 KB.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Token never arrives: you used pushType: nil (exercise 1) instead of .token.
//   Only a .token activity vends a pushToken.
//
// - APNs returns 400 BadDeviceToken / TopicDisallowed: the topic must be
//   `<bundle-id>.push-type.liveactivity` and the header `apns-push-type:
//   liveactivity`. A normal-notification topic is rejected for activities.
//
// - Push is accepted (200) but the Lock Screen doesn't change: the content-state
//   JSON doesn't match ContentState. Triple-check keys and that startedAt is a
//   NUMBER (seconds), not an ISO string. Encoding the Date with the default
//   strategy as a number is what ActivityKit expects.
//
// - Works with the app open but not when terminated: that means you were on the
//   LOCAL update path, not the push. Confirm you're pushing to the activity's
//   pushToken (from pushTokenUpdates), not calling activity.update() locally.
//
// - The token rotated and updates stopped: you only read the FIRST token. Observe
//   the whole `pushTokenUpdates` async stream and re-register on each new value.
//
// ----------------------------------------------------------------------------
