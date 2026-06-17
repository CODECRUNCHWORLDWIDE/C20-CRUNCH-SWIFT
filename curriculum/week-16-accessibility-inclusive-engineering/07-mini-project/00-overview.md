# Mini-Project — Notes v1: accessible edition

This week Notes v1 becomes usable by everyone. You will run the app **with VoiceOver enabled**, audit it with the **Accessibility Inspector**, fix **every** issue the audit and the screen-curtain pass surface, add **haptic feedback** on note creation, and ship a **Dynamic-Type-safe** list cell that renders correctly at the largest accessibility text size. The deliverable is a *measurable* result: the audit reports zero issues, the app is fully operable with the screen curtain on, and nothing clips at AX5 — proven with a screen recording.

This is a *compounding* project. It is not a new app. You start from Notes v1 — the same app you made fast on-device in Week 15 — and you make it operable, readable, and comfortable for users across the full range of human perception. No new features. The work is at the edges: labels, traits, the tree, Dynamic Type, motion, contrast, and haptics. The skill earned is the senior one: audit a SwiftUI app for accessibility and ship measurable improvements.

> The audit tools (Accessibility Inspector) run in the Simulator and need no membership. But VoiceOver and Dynamic Type are best experienced on the **physical device** you've had since Week 15 — the screen curtain, the rotor, the haptics. Test on the device.

---

## Where you're starting from

Your Notes v1 app has, roughly:

- A SwiftData notes list (`@Query`-driven), a detail editor, a tag editor, and a tag filter.
- Icon buttons (add, delete, share), maybe note cover images, status indicators.
- Animations (sheet presentation, list insertion), and standard SwiftUI controls.

If you don't have a clean Notes v1, a minimal SwiftData notes app with a list, a detail editor, tags, and a few icon buttons is enough — the accessibility work is the same.

## What you're building toward

By the end you have:

- A **zero-issue audit** — the Accessibility Inspector's automated audit reports no problems on every screen.
- **Full screen-curtain operability** — create, edit, tag, filter, and delete a note with VoiceOver and the screen black.
- A correct **accessibility tree** — every icon button labeled by purpose, decorative images hidden, cells merged into sensible elements, section titles as headers, swipe actions exposed via the rotor.
- A **Dynamic-Type-safe note cell** — renders correctly from default to AX5 with text styles, `@ScaledMetric`, and reflow.
- **Haptic feedback** on note creation (`.sensoryFeedback` / `UIImpactFeedbackGenerator`), respecting the user's settings.
- **Reduce-motion-aware** animations and **color-blind-safe** status signaling.
- A **screen recording** proving operability with the curtain on, and an `A11Y-REPORT.md` documenting every fix.

---

## Milestone 1 — Audit every screen (≈ 1 h)

Before fixing anything, *find* everything. For each screen (list, detail, tag editor, tag filter):

1. Run the app, open **Accessibility Inspector** (Xcode ▸ Open Developer Tool ▸ Accessibility Inspector).
2. Switch to the **Audit** tab, target the screen, **Run Audit**.
3. Record every reported issue in `A11Y-REPORT.md` as your "before" state — unlabeled elements, contrast failures, small targets, clipped-at-large-text warnings.

You now have a worklist, the same way an Instruments capture gave you a worklist last week.

## Milestone 2 — Fix the accessibility tree (≈ 2 h)

Work the list. Apply lecture-1 fixes across the app:

```swift
// Icon buttons -> purpose labels.
Button { addNote() } label: { Image(systemName: "plus") }
    .accessibilityLabel("Add note")

Button(role: .destructive) { delete(note) } label: { Image(systemName: "trash") }
    .accessibilityLabel("Delete note")

// The note cell -> one sensible element with a clean label.
struct NoteRow: View {
    let note: Note
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(.headline)
            Text(note.updatedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
            Text("\(note.tags?.count ?? 0) tags").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        // Expose the swipe actions through the rotor (lecture 1, §6.5).
        .accessibilityAction(named: "Delete") { delete(note) }
        .accessibilityAction(named: "Pin") { togglePin(note) }
    }
}

// Section titles -> headers (rotor-navigable).
Text("Pinned").font(.headline).accessibilityAddTraits(.isHeader)

// Decorative imagery -> hidden.
Image("paper-texture").accessibilityHidden(true)

// A custom tag chip that should be tappable -> .isButton + label.
TagChip(tag: tag)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("Tag: \(tag.name)")
    .accessibilityHint("Double-tap to filter by this tag")
```

Re-run the audit after each screen until it reports **zero**. Record the "after" state in `A11Y-REPORT.md`.

## Milestone 3 — The screen-curtain operability pass (≈ 1.5 h)

The audit catches the mechanical bugs; the curtain catches the experiential ones (lecture 1, §7). On the device:

1. Turn on **VoiceOver** (Settings ▸ Accessibility ▸ VoiceOver), set the Accessibility Shortcut to toggle it.
2. Turn on the **screen curtain** (three-finger triple-tap).
3. Complete the full flow blind: create → edit title → edit body → add a tag → filter by tag → delete. Note every place you get stuck.
4. Fix the experiential failures:
   - Focus stuck behind a presented sheet → `@AccessibilityFocusState` to move focus to the first field on appear.
   - A successful save/sync with no feedback → `UIAccessibility.post(notification: .announcement, argument: "Note saved")`.
   - A confusing reading order → `accessibilitySortPriority` or restructure the tree.
5. Re-run the flow with the curtain on until you can complete every task without getting stuck.

Record a screen capture of the full flow operated with the curtain on — this is the headline deliverable.

## Milestone 4 — Dynamic-Type-safe cell (≈ 1 h)

Make the note cell render correctly at AX5 (lecture 2, §1–2). Apply text styles, `@ScaledMetric`, reflow, and no fixed height (the exercise 2 pattern, applied to *your* cell):

```swift
struct NoteRow: View {
    let note: Note
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 18

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))

        layout {
            Image(systemName: "note.text")
                .font(.system(size: iconSize))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Text(note.updatedAt, style: .relative)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)              // no fixed height — grows with the text
        .accessibilityElement(children: .combine)
    }
}
```

Add `#Preview`s pinned to default and `.accessibility5`, and confirm in the canvas that nothing clips at AX5. Set the device to AX5 (Settings ▸ Display & Text Size ▸ Larger Text) and scroll the real list to confirm.

## Milestone 5 — Haptics on note creation (≈ 0.5 h)

Add a `.success` haptic when a note is created — confirmation the user can feel (lecture 2, §5):

```swift
struct NotesListView: View {
    @State private var createdCount = 0
    // ...
    var body: some View {
        List { /* ... */ }
            .toolbar {
                Button("Add note", systemImage: "plus") { addNote(); createdCount += 1 }
            }
            .sensoryFeedback(.success, trigger: createdCount)   // feel the create
    }
}
```

Keep it meaningful — a haptic on *create* and *delete*, not on every scroll or keystroke. The app must still work for users who've turned system haptics off.

## Milestone 6 — Reduce-motion and contrast pass (≈ 0.5 h)

1. **Reduce motion:** find your sheet/insertion animations and swap them to a fade under `\.accessibilityReduceMotion` (lecture 2, §3). Test with Settings ▸ Accessibility ▸ Motion ▸ Reduce Motion on.
2. **Contrast / color:** find any color-only signal (a status dot, a "synced" indicator) and add a shape/icon and an `accessibilityLabel` (lecture 2, §4). Test under a color-blindness filter and confirm the audit's contrast checks pass — use semantic colors (`.primary`, `.secondary`) for text.

---

## A worked `A11Y-REPORT.md` entry

So you know the bar for the report, here's the shape of one good entry:

> **List screen — Add button.** Before: VoiceOver announced "plus, button" (the SF Symbol name). Audit flagged "element may not have a meaningful label." Fix: `.accessibilityLabel("Add note")`. After: announces "Add note, button"; audit clean.
>
> **List screen — note cell.** Before: three VoiceOver stops per cell ("Groceries", "2 hours ago", "3 tags") — tedious. Fix: `.accessibilityElement(children: .combine)`. After: one stop, "Groceries, 2 hours ago, 3 tags".
>
> **List screen — swipe-to-delete.** Before: delete was swipe-only and unreachable by VoiceOver. Fix: `.accessibilityAction(named: "Delete")`. After: reachable via the actions rotor.
>
> **Detail screen — edit sheet.** Before: sheet appeared but focus stayed on the list behind it. Fix: `@AccessibilityFocusState` to focus the title field on appear. After: focus lands on the title, ready to type.
>
> **Detail screen — note cell at AX5.** Before: title clipped at AX5 (fixed 44pt height). Fix: padding instead of fixed height, reflow to vertical, `@ScaledMetric` icon. After: renders fully at AX5, no clip.

Each entry: the screen, the symptom, the fix, the verified after-state. A reviewer reads it and knows exactly what was broken and how you proved it fixed.

## Acceptance criteria

- [ ] The **automated audit reports zero issues** on every screen (before/after recorded in `A11Y-REPORT.md`).
- [ ] **Full screen-curtain operability**: create, edit, tag, filter, delete — all completable with VoiceOver and the screen black, proven by a **screen recording**.
- [ ] The **accessibility tree is correct**: icon buttons labeled by purpose, decorative images hidden, cells merged, section titles as headers, swipe actions exposed via the rotor.
- [ ] The **note cell renders without clipping at AX5** (text styles, `@ScaledMetric`, reflow, no fixed height; AX5 preview included).
- [ ] **Haptic feedback** on note creation (`.sensoryFeedback`/`UIImpactFeedbackGenerator`), meaningful and respectful of settings.
- [ ] **Animations honor reduce-motion**, and **no state is signaled by color alone**.
- [ ] The Week 15 performance fixes and earlier functionality **still work** unchanged.
- [ ] Build with **0 warnings, 0 errors**.

## Stretch goals

- **Accessibility UI test in CI.** Add an XCUITest that asserts key buttons' labels and runs `performAccessibilityAudit()`, so an accessibility regression fails the build (homework problem 6, applied to Notes v1).
- **Custom rotor.** Add a custom VoiceOver rotor for "tags" so a user can spin to jump between tags in a long note.
- **Adjustable rating/priority.** If a note has a priority, make it an `accessibilityAdjustableAction` control the user changes by swiping up/down in VoiceOver.
- **Voice Control pass.** Turn on Voice Control and confirm "tap Add note", "tap Delete" work — a free benefit of the labels you added, and proof the tree serves more than VoiceOver.

## What this milestone earns you

You can now audit a SwiftUI app for accessibility and ship measurable improvements — the literal "skill earned" line for the week. More than that: you proved the app is operable by someone who can't see the screen, readable by someone at the largest text size, and comfortable for users with motion sensitivity or color blindness — and you proved it with a tool and a recording, not an assertion. Week 17 returns to the security thread (CryptoKit, the Secure Enclave, certificate pinning), audited and fixed to a measurable bar the same way. You've made the app fast, then usable by everyone; next you make it secure.
