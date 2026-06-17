# Exercise 1 — Audit a screen and fix every label

**Goal.** Run the Accessibility Inspector's automated audit on a deliberately broken screen, read its reported issues the way you read an Instruments trace, and fix every one — the unlabeled icon buttons, the decorative-image noise VoiceOver announces, the missing header traits, the small hit targets — until the audit reports zero. This is the audit-find-fix loop the whole week is built on, in one screen.

**Estimated time.** 40 minutes.

**Prerequisites.** Xcode 16+ and the Accessibility Inspector (Xcode ▸ Open Developer Tool ▸ Accessibility Inspector). A device is ideal for the VoiceOver pass but the audit runs in the Simulator. We build a small `BrokenScreen` so the focus stays on the audit.

---

## Step 1 — Build the deliberately broken screen

Scaffold a SwiftUI app `A11yScratch`. Replace `ContentView.swift` with a screen that commits the common accessibility footguns:

```swift
import SwiftUI

struct ContentView: View {
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // FOOTGUN 1: a "section title" that isn't marked as a header.
                Text("Quick Actions")
                    .font(.title2.bold())

                HStack(spacing: 24) {
                    // FOOTGUN 2: icon-only button, no label. VoiceOver reads "heart" / "trash".
                    Button { isFavorite.toggle() } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                    }
                    Button { } label: { Image(systemName: "trash") }
                    Button { } label: { Image(systemName: "square.and.arrow.up") }
                }
                .font(.title)

                // FOOTGUN 3: a decorative image announced as noise.
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)

                // FOOTGUN 4: color-only status — invisible to color-blind users, and
                // the dot has no label so VoiceOver says nothing useful.
                HStack {
                    Circle().fill(isFavorite ? .green : .red).frame(width: 12, height: 12)
                    Text(isFavorite ? "Saved" : "Not saved")
                }
            }
            .padding()
            .navigationTitle("Broken")
        }
    }
}

#Preview { ContentView() }
```

Run it. It *looks* fine. The bugs are all in the accessibility tree.

## Step 2 — Run the automated audit

1. Run the app in the Simulator.
2. Open **Accessibility Inspector** (Xcode ▸ Open Developer Tool ▸ Accessibility Inspector).
3. In the Inspector, set the target to your Simulator, switch to the **Audit** tab, and click **Run Audit**.
4. Read the reported issues. You should see things like: *"Element may not have a label"* (the icon buttons), *"Potentially inaccessible text"* or contrast warnings, and possibly hit-target warnings.

Write the issues into `notes/audit-before.md` — the raw list, before you fix anything. This is your "before" state.

## Step 3 — Fix each issue

Apply the fixes from lecture 1:

```swift
import SwiftUI

struct ContentView: View {
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // FIX 1: mark the section title as a header (rotor-navigable).
                Text("Quick Actions")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 24) {
                    // FIX 2: label each icon button by PURPOSE; value carries the toggle state.
                    Button { isFavorite.toggle() } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                    }
                    .accessibilityLabel("Favorite")
                    .accessibilityValue(isFavorite ? "On" : "Off")

                    Button { } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete")

                    Button { } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share")
                }
                .font(.title)

                // FIX 3: hide the decorative image from the tree.
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                // FIX 4: status carries shape + label, not color alone; merge into one element.
                HStack {
                    Image(systemName: isFavorite ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(isFavorite ? .green : .red)
                    Text(isFavorite ? "Saved" : "Not saved")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isFavorite ? "Status: saved" : "Status: not saved")
            }
            .padding()
            .navigationTitle("Broken")
        }
    }
}
```

## Step 4 — Re-run the audit and verify with VoiceOver

1. Re-run the **Audit** — it should now report **zero** (or only false-positive) issues. Record the result in `notes/audit-after.md`.
2. If you have a device, turn on **VoiceOver** and swipe through the screen with the **screen curtain** on. Confirm: each button announces its purpose ("Favorite, on"), the decorative sparkle is *skipped*, the section title is reachable via the headings rotor, and the status reads meaningfully.

---

## Acceptance criteria

- [ ] You ran the **automated audit** on the broken screen and recorded the issues in `notes/audit-before.md`.
- [ ] Every icon-only button has a purposeful `accessibilityLabel` (not the SF Symbol name), and the toggle carries an `accessibilityValue`.
- [ ] The decorative image is `accessibilityHidden(true)`.
- [ ] The section title has the `.isHeader` trait.
- [ ] The status uses a shape + label (not color alone) and reads as one sensible element.
- [ ] The re-run audit reports **zero** issues (recorded in `notes/audit-after.md`).
- [ ] (If you have a device) You verified the screen is sensible under VoiceOver with the curtain on.
- [ ] Build with **0 warnings, 0 errors**.

## What you just proved

You ran the loop the entire week is built on: audit → find the mechanical failures → fix each with the right modifier → re-audit to zero. You turned a screen that *looked* fine but was full of accessibility dead ends into one VoiceOver navigates cleanly. Every other exercise and the mini-project is this loop, applied to bigger surfaces.

---

## Hints (read only if stuck > 10 min)

- **The audit reports nothing.** Make sure the app is running and the Inspector is targeting the right Simulator/process. The Audit tab's target picker must point at your app.
- **VoiceOver reads "Favorite, Favorite".** You put the state in the label *and* the value, or labeled it "Favorite button" (VoiceOver adds "button" itself). Label = purpose only; value = state only; no redundant type.
- **The audit still flags the status dot.** A bare `Circle` with no label is an unlabeled image-like element. Combining the row into one element with a label (FIX 4) resolves it.
- **`.isHeader` doesn't seem to do anything.** It's only observable via the *headings rotor* in VoiceOver — turn on VoiceOver, two-finger-twist to "Headings", and swipe; the title should be a stop. The audit may not flag a missing header, but it materially improves navigation.
