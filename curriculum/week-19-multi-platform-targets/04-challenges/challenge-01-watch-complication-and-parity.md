# Challenge 1 — A watch complication + a five-platform parity matrix

**Time.** 90–150 minutes.
**Deliverable.** The complication code, screenshots of it on the watch face (simulator), and a `PARITY.md` with a feature × platform matrix proving the shared core behaves identically across all five surfaces — committed to your Week 19 repo.

## The premise

The phrase "one codebase, five platforms" is easy to say and hard to *prove*. This challenge makes you prove it two ways. First you build a watch **complication** — a glanceable widget on the watch face showing the live note count — and wire it to the *same* `NotesCore` the phone uses, so the wrist is reading the identical data through the identical logic. Then you produce a **parity matrix**: a feature-by-platform table that audits where the share/adapt line falls, confirming the *behavior* is identical (shared core) while the *shell* differs per platform (adapted presentation). The skill this builds is not "I made an app run on the Mac" — it's **prove the core is genuinely shared and be honest about what each platform should and shouldn't do.** A multi-platform claim you can't audit is a multi-platform claim you're making on faith.

## Part 1 — The watch complication

Start from your Notes Pro multi-platform app (or the exercise-3 `NotesCore` package + a watchOS target). Add a **WidgetKit extension** for the watch and build a complication that shows the note count.

### Step 1 — A timeline provider reading the shared core

```swift
import WidgetKit
import SwiftUI
import NotesCore

struct CountEntry: TimelineEntry {
    let date: Date
    let count: Int
}

struct CountProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountEntry { CountEntry(date: .now, count: 0) }

    func getSnapshot(in context: Context, completion: @escaping (CountEntry) -> Void) {
        completion(CountEntry(date: .now, count: NotesCore.currentNoteCount()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountEntry>) -> Void) {
        // The count comes from the SAME core the phone uses. Reload when notes change.
        let entry = CountEntry(date: .now, count: NotesCore.currentNoteCount())
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}
```

### Step 2 — Render it in the accessory families

```swift
struct NoteCountComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NoteCount", provider: CountProvider()) { entry in
            ViewThatFits {
                Label("\(entry.count) notes", systemImage: "note.text")  // rectangular
                Text("\(entry.count)")                                   // circular
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "notes://open"))   // tap -> open the app
        }
        .configurationDisplayName("Note Count")
        .description("How many notes you have.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
```

### Step 3 — Reload on change

When the app adds or deletes a note, refresh the complication so the face stays live:

```swift
import WidgetKit

func notesDidChange() {
    WidgetCenter.shared.reloadTimelines(ofKind: "NoteCount")
}
```

### Step 4 — Prove it on the watch face

In the watchOS simulator, add the complication to a watch face (long-press the face ▸ Edit ▸ add the complication to a slot). Confirm the count shows, then add a note in the app and confirm the face updates (you may need to trigger `reloadTimelines` or wait for the budget). Screenshot the face with the complication showing the live count.

## Part 2 — The parity matrix

Now audit the share/adapt line. Run the app on as many surfaces as you can boot — iPhone, iPad, Mac (native), Watch, and Vision simulators — and fill in a matrix. The columns prove two things at once: that the *behavior* (what notes, what count, what order) is identical because it flows through `NotesCore`, and that the *shell* differs appropriately per platform.

Produce a table like this in `PARITY.md`, filled with what your app actually does:

| Feature | iPhone | iPad | Mac | Watch | Vision | Behavior shared? |
|---------|--------|------|-----|-------|--------|------------------|
| List notes | stack | split (2col) | split (3col) | glance (3) | window | ✓ same query/sort |
| Note count | toolbar | toolbar | toolbar | complication | toolbar | ✓ `NotesDomain.summary` |
| Open a note | push | detail col | detail col | push (read-only) | detail col | ✓ same model |
| Add a note | ✓ | ✓ | ✓ + ⌘N | — (by design) | ✓ | ✓ same insert path |
| Search | ✓ | ✓ | ✓ | — (by design) | ✓ | ✓ `NotesDomain.matching` |

For each row, the **"Behavior shared?"** column must cite the *shared* code path (the `NotesCore` function or model) that guarantees identical behavior. The per-platform cells describe the *shell*. And where a feature is honestly *absent by design* (composing a long note on a watch, searching on a wrist), mark it `— (by design)` and say so in a sentence below the table — that honesty is the senior judgment, not a gap to apologize for.

## Acceptance criteria

- [ ] A watchOS **complication** (a WidgetKit widget) shows the note count, sourced from the **shared `NotesCore`**, in at least two accessory families.
- [ ] The complication **reloads** when notes change (`WidgetCenter.reloadTimelines`).
- [ ] A screenshot of the complication on a watch face in the simulator showing the live count.
- [ ] A `PARITY.md` matrix covering at least four platforms (five if you can boot Vision), with a **"Behavior shared?"** column citing the `NotesCore` path for each feature.
- [ ] At least one feature honestly marked **absent by design** for a platform, with a one-sentence justification.
- [ ] A 3–5 sentence reflection on where the share/adapt line fell and one place you were tempted to fork but didn't.
- [ ] Build with **0 warnings** on every target.

## What "great" looks like

A weak submission says "it runs on the watch and the Mac." A great submission says:

> The complication reads `NotesDomain.summary(notes)` from `NotesCore` — the exact function the iPhone toolbar count uses — so the wrist and the phone can never disagree about the count; I proved it by adding a note on the phone and watching the face update after a `reloadTimelines`. The parity matrix shows the behavior is shared on every row (each cites a `NotesCore` path) while the shell adapts: a three-column split on the Mac, a glanceable three-note list on the Watch, a floating window on Vision. I deliberately marked "compose a long note" and "search" as absent-by-design on the Watch — cramming a text editor onto a wrist would make a worse app, and the honest gap is the right call, not a missing feature. The one place I was tempted to fork was the note row, which looks different on each platform; instead I kept one `NoteRow` view and let Dynamic Type and the container size adapt it, so it's still shared.

Provable sharing, honest gaps, resisted forks. That's the senior-engineer answer, and it's the capstone's multi-platform-parity rubric in miniature.

## Where this reappears

The capstone scores **multi-platform parity (iPhone + iPad + Mac + watchOS + visionOS)** at 15 points, and this matrix is exactly how you'll demonstrate it. The complication is also your on-ramp to Week 20's full WidgetKit work (Home Screen and Lock Screen widgets, richer timelines, App Intents). You've now proven the shared core feeds a glanceable face and audited the line across five platforms — the foundation everything in Phase IV stands on.
