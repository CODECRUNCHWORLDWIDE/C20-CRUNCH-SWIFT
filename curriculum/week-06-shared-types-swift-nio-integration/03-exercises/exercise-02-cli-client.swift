// Exercise 2 — A URLSession CLI client that consumes notes-api via NotesCore
//
// Goal: Build a runnable Swift CLI, `notes-cli`, that talks to your running
//       Week 5 notes-api over HTTP using the SHARED NotesCore types. It should:
//
//         notes-cli list
//         notes-cli create "Title" "Body" tag1,tag2
//         notes-cli get <uuid>
//
//       The decode target is NotesCore.Note — the exact type the server
//       encoded. No re-declared client structs. That is the whole point.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Create an executable package beside NotesCore and notes-api:
//
//        cd notes-workspace
//        mkdir notes-cli && cd notes-cli
//        swift package init --type executable --name notes-cli
//
//   2. Replace notes-cli/Package.swift with the manifest in HINT 0 below.
//
//   3. Replace Sources/notes-cli/main.swift (or notes_cli.swift) with THIS FILE.
//
//   4. Fill in the four TODOs.
//
//   5. With the server running (`cd ../notes-api && swift run`, Postgres up),
//      run the client:
//
//        cd ../notes-cli
//        swift run notes-cli create "Buy oat milk" "The barista kind" groceries,urgent
//        swift run notes-cli list
//        swift run notes-cli get <the-uuid-printed-above>
//
// ACCEPTANCE CRITERIA
//
//   [ ] `notes-cli create` POSTs a CreateNoteRequest and prints the returned Note's id.
//   [ ] `notes-cli list` GETs /notes and prints one line per note.
//   [ ] `notes-cli get <uuid>` GETs /notes/:id and prints the note, or a clean
//       "not found" message on 404.
//   [ ] Responses decode into NotesCore.Note — no client-local Note struct.
//   [ ] Date strategy matches the server (.iso8601 on both ends).
//   [ ] A non-2xx response is decoded into NotesCore.APIError and its `reason`
//       is surfaced — not a raw status code dump.
//   [ ] `swift build` succeeds with 0 warnings, 0 errors under Swift 6 mode.
//
// EXPECTED OUTPUT (yours will differ by id and timestamps)
//
//   $ swift run notes-cli create "Buy oat milk" "The barista kind" groceries,urgent
//   Created note 7F3A1C2E-... "Buy oat milk"
//
//   $ swift run notes-cli list
//   7F3A1C2E-...  Buy oat milk           [groceries, urgent]
//   1B9D4F00-...  Call the dentist       []
//
//   $ swift run notes-cli get 00000000-0000-0000-0000-000000000000
//   Error: No note with that id
//
// Inline hints at the bottom of the file.

import Foundation
import NotesCore

// MARK: - Configuration

/// Base URL of the running notes-api. Override with NOTES_API_URL if you like.
let baseURL: URL = {
    if let raw = ProcessInfo.processInfo.environment["NOTES_API_URL"],
       let url = URL(string: raw) {
        return url
    }
    return URL(string: "http://127.0.0.1:8080")!
}()

/// Bearer token for the auth middleware from Week 5. Override with NOTES_API_TOKEN.
let bearerToken: String =
    ProcessInfo.processInfo.environment["NOTES_API_TOKEN"] ?? "dev-token"

// MARK: - Client errors

enum ClientError: Error, CustomStringConvertible {
    case badStatus(Int, APIError?)
    case malformedResponse(String)
    case usage(String)

    var description: String {
        switch self {
        case .badStatus(let code, let apiError):
            if let apiError { return apiError.reason }
            return "Server returned HTTP \(code)"
        case .malformedResponse(let detail):
            return "Malformed response: \(detail)"
        case .usage(let message):
            return message
        }
    }
}

// MARK: - JSON coders (strategies MUST match the server)

func makeEncoder() -> JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}

func makeDecoder() -> JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}

// MARK: - The HTTP plumbing

/// Performs a request and returns the response body data, throwing a typed
/// ClientError on any non-2xx status (decoding the body into APIError first).
func send(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw ClientError.malformedResponse("Response was not HTTP")
    }
    guard (200..<300).contains(http.statusCode) else {
        // TODO 1 — On a non-2xx response, try to decode the body into an
        // APIError (the { "error": true, "reason": "..." } envelope) and
        // throw ClientError.badStatus(statusCode, decodedAPIError). If the
        // body is not a valid APIError, throw .badStatus(statusCode, nil).
        //
        // Reminder: makeDecoder().decode(APIError.self, from: data) may throw;
        // catch it and fall back to nil.
        fatalError("TODO 1 not implemented")
    }
    return data
}

/// Builds a URLRequest for `path` with the bearer header set.
func request(_ method: String, _ path: String) -> URLRequest {
    var req = URLRequest(url: baseURL.appendingPathComponent(path))
    req.httpMethod = method
    req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    return req
}

// MARK: - The three commands

func createNote(title: String, body: String, tags: [String]) async throws {
    var req = request("POST", "notes")
    let payload = CreateNoteRequest(title: title, body: body, tags: tags)

    // TODO 2 — Encode `payload` with makeEncoder() into req.httpBody, send the
    // request, decode the response Data into a NotesCore.Note, and print:
    //
    //   Created note <id> "<title>"
    //
    // Wrap the decode in a do/catch that maps DecodingError into
    // ClientError.malformedResponse with the failing coding path (see HINT 3).
    fatalError("TODO 2 not implemented")
}

func listNotes() async throws {
    let data = try await send(request("GET", "notes"))

    // TODO 3 — Decode `data` into [NotesCore.Note] and print one line per note:
    //
    //   <id>  <title padded to 22 cols>  [<comma-joined tags>]
    //
    // Use String(format:) or padding to align columns; exact spacing is cosmetic.
    fatalError("TODO 3 not implemented")
}

func getNote(idString: String) async throws {
    guard UUID(uuidString: idString) != nil else {
        throw ClientError.usage("Not a valid UUID: \(idString)")
    }
    let data = try await send(request("GET", "notes/\(idString)"))

    // TODO 4 — Decode `data` into a NotesCore.Note and print it on two lines:
    //
    //   <title>  (<id>)
    //   <body>
    //
    // The 404 case is already handled for you: send() throws
    // ClientError.badStatus with the APIError reason, which main() prints.
    fatalError("TODO 4 not implemented")
}

// MARK: - Argument parsing and entry point

func run() async throws {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        throw ClientError.usage("Usage: notes-cli <list|create|get> ...")
    }
    args.removeFirst()

    switch command {
    case "list":
        try await listNotes()

    case "create":
        guard args.count >= 2 else {
            throw ClientError.usage(#"Usage: notes-cli create "Title" "Body" [tag1,tag2]"#)
        }
        let title = args[0]
        let body = args[1]
        let tags = args.count >= 3
            ? args[2].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            : []
        try await createNote(title: title, body: body, tags: tags)

    case "get":
        guard let id = args.first else {
            throw ClientError.usage("Usage: notes-cli get <uuid>")
        }
        try await getNote(idString: id)

    default:
        throw ClientError.usage("Unknown command: \(command)")
    }
}

// Top-level async entry. On Linux and macOS this drives the async work to
// completion and maps any thrown ClientError to a clean stderr line + exit 1.
do {
    try await run()
} catch let error as ClientError {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(1)
}

// ===========================================================================
// HINTS — peek only if stuck.
// ===========================================================================
//
// HINT 0 — notes-cli/Package.swift:
//
//   // swift-tools-version:6.0
//   import PackageDescription
//
//   let package = Package(
//       name: "notes-cli",
//       platforms: [.macOS(.v14)],
//       dependencies: [
//           .package(path: "../NotesCore")
//       ],
//       targets: [
//           .executableTarget(
//               name: "notes-cli",
//               dependencies: [.product(name: "NotesCore", package: "NotesCore")],
//               swiftSettings: [.swiftLanguageMode(.v6)]
//           )
//       ]
//   )
//
// HINT 1 — TODO 1 (non-2xx handling) in send():
//
//   let apiError = try? makeDecoder().decode(APIError.self, from: data)
//   throw ClientError.badStatus(http.statusCode, apiError)
//
// HINT 2 — TODO 2 (createNote):
//
//   req.httpBody = try makeEncoder().encode(payload)
//   let data = try await send(req)
//   do {
//       let note = try makeDecoder().decode(Note.self, from: data)
//       print(#"Created note \#(note.id) "\#(note.title)""#)
//   } catch {
//       throw mapDecodingError(error)
//   }
//
// HINT 3 — A reusable DecodingError mapper (add near the coders):
//
//   func mapDecodingError(_ error: Error) -> ClientError {
//       switch error {
//       case let DecodingError.keyNotFound(key, ctx):
//           return .malformedResponse("missing '\(key.stringValue)' at \(path(ctx))")
//       case let DecodingError.typeMismatch(type, ctx):
//           return .malformedResponse("expected \(type) at \(path(ctx))")
//       case let DecodingError.valueNotFound(type, ctx):
//           return .malformedResponse("null where \(type) required at \(path(ctx))")
//       case let DecodingError.dataCorrupted(ctx):
//           return .malformedResponse("corrupted: \(ctx.debugDescription)")
//       default:
//           return .malformedResponse("\(error)")
//       }
//   }
//   func path(_ ctx: DecodingError.Context) -> String {
//       ctx.codingPath.map(\.stringValue).joined(separator: ".")
//   }
//
// HINT 4 — TODO 3 (listNotes):
//
//   let notes = try makeDecoder().decode([Note].self, from: data)
//   for note in notes {
//       let title = note.title.padding(toLength: 22, withPad: " ", startingAt: 0)
//       print("\(note.id)  \(title)  [\(note.tags.joined(separator: ", "))]")
//   }
//
// HINT 5 — TODO 4 (getNote):
//
//   let note = try makeDecoder().decode(Note.self, from: data)
//   print("\(note.title)  (\(note.id))")
//   print(note.body)
//
// REFLECTION QUESTIONS — answer in results-ex02.md:
//
//   1. You never declared a `Note` struct in this file. Where did the type the
//      decoder produced come from, and why does that matter for correctness?
//   2. If the server switched `createdAt` from ISO-8601 to epoch seconds and
//      you did NOT change this client, what exact error would you see, and at
//      what coding path?
//   3. The bearer token is read from an env var with a "dev-token" default.
//      Name two reasons that default is acceptable for this exercise and
//      unacceptable for a shipped binary.
//   4. `URLSession.shared.data(for:)` is `async`. Trace what happens on the
//      server's event loop while this client is awaiting the response.
