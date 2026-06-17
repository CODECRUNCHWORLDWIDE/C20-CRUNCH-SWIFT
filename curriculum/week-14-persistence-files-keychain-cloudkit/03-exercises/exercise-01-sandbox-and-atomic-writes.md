# Exercise 1 — The sandbox and atomic writes

**Goal.** Make the "right place for each byte" decision tree concrete. You will write the same document to three different sandbox directories, understand the backup-and-purge consequence of each, write it **atomically** so a crash can't corrupt it, exclude a cache file from backup, and then *prove* the placement by inspecting the on-disk sandbox with the file inspector. By the end you will never again ask "where do I put this file?" — you'll run the tree.

**Estimated time.** 40 minutes.

**Prerequisites.** Xcode 16+, an iOS 18 Simulator (iOS 17 works; every API here is iOS 16+). The Notes app is *not* required — we build a throwaway `FilesScratch` app so the focus stays on the file system. You'll do the real persistence work in the mini-project.

---

## Step 1 — Scaffold a fresh SwiftUI app

In Xcode: **File ▸ New ▸ Project ▸ iOS ▸ App.** Name it `FilesScratch`, Interface **SwiftUI**, Storage **None**. Set the deployment target to iOS 17.0 or later. Confirm it builds and runs.

## Step 2 — A document type and the directory map

Create `Storage.swift`:

```swift
import Foundation

struct Draft: Codable, Equatable {
    var title: String
    var body: String
    var savedAt: Date
}

enum StorageLocation {
    /// User data the user would be upset to lose. Backed up to iCloud.
    case documents
    /// App's own data files. Backed up, hidden from the user.
    case applicationSupport
    /// Regenerable. NOT backed up. The OS may delete this under pressure.
    case caches

    var directory: URL {
        switch self {
        case .documents:          URL.documentsDirectory
        case .applicationSupport: URL.applicationSupportDirectory
        case .caches:             URL.cachesDirectory
        }
    }
}

enum DraftStore {
    /// Atomic write to the chosen location. A crash mid-write leaves the OLD
    /// file intact, never a half-written one.
    static func save(_ draft: Draft, named name: String, to location: StorageLocation) throws -> URL {
        let dir = location.directory
        // Application Support may not exist on first launch; create it.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: name).appendingPathExtension("json")
        let data = try JSONEncoder().encode(draft)
        try data.write(to: url, options: .atomic)   // <- the whole point of atomicity
        return url
    }

    static func load(named name: String, from location: StorageLocation) throws -> Draft {
        let url = location.directory.appending(path: name).appendingPathExtension("json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Draft.self, from: data)
    }

    /// Keep a file in a backed-up directory but skip it in backups (large caches).
    static func excludeFromBackup(_ url: URL) throws {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
```

## Step 3 — A screen that writes to all three, and prints the paths

Replace `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var log: [String] = []

    var body: some View {
        NavigationStack {
            List(log, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)) }
                .navigationTitle("Files Scratch")
                .toolbar {
                    Button("Write all three", action: writeAll)
                }
        }
    }

    private func writeAll() {
        log.removeAll()
        let draft = Draft(title: "Hello", body: "world", savedAt: .now)
        do {
            let docs = try DraftStore.save(draft, named: "draft", to: .documents)
            log.append("documents  -> \(docs.path())")

            let support = try DraftStore.save(draft, named: "draft", to: .applicationSupport)
            log.append("appSupport -> \(support.path())")

            let cache = try DraftStore.save(draft, named: "thumbnail", to: .caches)
            try DraftStore.excludeFromBackup(cache)   // a cache: not in backups
            log.append("caches     -> \(cache.path()) (excluded from backup)")

            // Prove the round-trip from one of them.
            let loaded = try DraftStore.load(named: "draft", from: .applicationSupport)
            log.append("round-trip OK: \(loaded == draft)")
        } catch {
            log.append("ERROR: \(error)")
        }
    }
}

#Preview { ContentView() }
```

## Step 4 — Run it and read the paths

Run on the Simulator and tap **Write all three**. You'll see three paths print, each under a different `Library/` subfolder or `Documents`. Note that `Caches` is under `Library/Caches` and `Application Support` is under `Library/Application Support` — the layout from lecture 1, §2.

## Step 5 — Inspect the sandbox from the command line

Prove the files landed where you think, and see the backup-and-purge distinction physically:

```bash
# Find the app's data container.
DATA=$(xcrun simctl get_app_container booted com.yourname.FilesScratch data)
echo "$DATA"

# The three files, in their three homes.
ls -la "$DATA/Documents/"
ls -la "$DATA/Library/Application Support/"
ls -la "$DATA/Library/Caches/"

# Read one back — it's plain JSON on disk.
cat "$DATA/Documents/draft.json"

# Confirm the cache file carries the "exclude from backup" extended attribute.
xattr -l "$DATA/Library/Caches/thumbnail.json"   # look for com.apple.metadata:com_apple_backup_excludeItem
```

Replace `com.yourname.FilesScratch` with your actual bundle id (Xcode ▸ target ▸ Signing & Capabilities ▸ Bundle Identifier).

## Step 6 — Prove the atomic write protects you (thought experiment + demo)

Atomic write means a crash mid-write never corrupts the file. You can demonstrate the mechanism: replace the atomic write with a *deliberately* non-atomic, interruptible one and observe the difference in principle.

```swift
// Add this to DraftStore to SEE the non-atomic hazard (don't ship it):
static func saveNonAtomic(_ draft: Draft, named name: String, to location: StorageLocation) throws -> URL {
    let url = location.directory.appending(path: name).appendingPathExtension("json")
    let data = try JSONEncoder().encode(draft)
    // Truncate the file FIRST, then write — a crash between these leaves it empty/partial.
    try Data().write(to: url)         // file is now empty
    try data.write(to: url)           // a crash before this line = data loss
    return url
}
```

The lesson, in one sentence to write in your notes: with `.atomic`, the file on disk is *always* either the complete old contents or the complete new contents, because the write goes to a temp file and is renamed into place; the non-atomic version has a window where the file is empty or partial, and a crash in that window loses data.

---

## Acceptance criteria

- [ ] `DraftStore.save` writes with `options: .atomic`, and `StorageLocation` maps the three directories to their correct `URL` accessors.
- [ ] The app writes the same draft to `documents`, `applicationSupport`, and `caches`, and prints all three resolved paths.
- [ ] The cache file has `isExcludedFromBackup` set; you confirmed the extended attribute with `xattr -l`.
- [ ] A load round-trips: the decoded `Draft` equals the one you saved.
- [ ] Build with **0 warnings, 0 errors**.
- [ ] In `notes/storage-placement.md`, you wrote one sentence each on: which directory is *not* backed up, which the OS may *delete* under storage pressure, and why a 200 MB video cache must not go in `Documents`.

## What you just proved

You ran the "right place for each byte" tree for real: three files, three directories, three backup-and-purge consequences. You wrote atomically, so a crash can't corrupt a file. And you excluded a cache from backup so it won't eat the user's iCloud quota. This is the file-system half of the week's promise — *no file write is corruptible by a crash* — and it is the foundation the mini-project builds the Keychain and CloudKit halves on top of.

---

## Hints (read only if stuck > 10 min)

- **`Application Support` write fails with "no such file or directory."** It doesn't exist until you create it. `createDirectory(withIntermediateDirectories: true)` before every write to it — it's idempotent and safe to call repeatedly.
- **`xattr -l` shows nothing on the cache file.** `setResourceValues` mutates a *copy* of the `URL`, so you must call it on a `var url` and the value sticks to the path, not the variable. Make sure you passed the actual file URL returned from `save`, and that `excludeFromBackup` ran *after* the file existed.
- **`simctl` says "No devices are booted."** Run the app from Xcode first so a simulator is booted, then run the `simctl` commands against `booted`.
- **The cache file vanished between runs.** That's the OS purging `Caches` under storage pressure (or you reset the simulator). That's the *feature* — never store anything in `Caches` you can't regenerate.
