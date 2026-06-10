# Exercise 1 — Deploy a Release build and read the profile

**Goal.** Close the whole week's core loop once: sign and deploy a Release build to a physical device you own, run the Time Profiler while you exercise the app, and read the resulting flame graph to find the single heaviest stack. By the end you will have done — on real silicon, with real numbers — the thing every later exercise and the mini-project repeat: *device tells the truth, Instruments reads it, you find the spike.*

**Estimated time.** 40 minutes.

**Prerequisites.** Xcode 16+, a **physical iPhone or iPad** on iOS 17+/18, and a **paid Apple Developer account** (both required this week). The app under test can be Notes v1 or the small `Profilee` app below — we use a deliberately heavy screen so the profiler has something obvious to find.

---

## Step 1 — A deliberately heavy screen

Scaffold a SwiftUI app `Profilee` (Storage: None). Add a screen that does too much synchronous work, so the profiler has a clear target:

```swift
import SwiftUI

struct ContentView: View {
    @State private var items: [String] = []

    var body: some View {
        NavigationStack {
            List(items, id: \.self) { item in
                // expensiveHash runs on the MAIN THREAD as each row renders.
                Text("\(item) — \(expensiveHash(item))")
            }
            .navigationTitle("Profilee (\(items.count))")
            .toolbar {
                Button("Load 2,000") { items = (0..<2_000).map { "Item \($0)" } }
            }
        }
    }

    /// Intentionally slow: a tight loop so it shows up as a self-time spike.
    func expensiveHash(_ s: String) -> Int {
        var h = 0
        for _ in 0..<5_000 {
            for ch in s.unicodeScalars { h = (h &* 31 &+ Int(ch.value)) & 0xFFFF }
        }
        return h
    }
}

#Preview { ContentView() }
```

This is a footgun on purpose: `expensiveHash` runs on the main thread for every visible row, so scrolling does heavy CPU work on the UI thread. We want the profiler to point right at it.

## Step 2 — Switch to Release and deploy to the device

1. **Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Build Configuration → Release.** (Performance numbers require Release; Debug is unoptimized and lies.)
2. Connect and unlock your device; select it in the run-destination picker.
3. **⌘R.** Xcode signs (automatic signing, from lecture 1), installs, and launches on the device. If you hit a signing error, work the troubleshooting chain from lecture 1, §7 + the worked flow.
4. On the device, tap **Load 2,000** and scroll. Notice it doesn't feel as smooth as the Simulator did — that's the device telling the truth.

## Step 3 — Profile with the Time Profiler

1. **Product ▸ Profile** (⌘I). Xcode builds the Release config and launches Instruments.
2. Choose the **Time Profiler** template. Click **Record** (red button).
3. On the device, tap **Load 2,000** and scroll vigorously for ~10 seconds.
4. **Stop** the recording.

## Step 4 — Read the flame graph

In the Time Profiler trace:

1. Select the **main thread** track (the cost that hurts the UI lives here).
2. Open the **Call Tree** (bottom). Enable **"Invert Call Tree"** off and **"Hide System Libraries"** on so your code stands out.
3. Expand down the heaviest path, following **total time** until **self time** spikes. You should land on `expensiveHash` (or the loop inside it) holding the large self time.
4. Use the inspector's **"Heaviest Stack Trace"** to confirm — it shows the single hottest path, ending at your expensive function.

Write into `notes/profile-reading.md`: the function with the highest **self time**, the thread it ran on (main), and one sentence on why running it on the main thread during scroll is the problem.

## Step 5 — Confirm the diagnosis, don't fix it yet

You don't have to fix `expensiveHash` in this exercise (exercise 2 is the fix drill). The point here is *reading* the profile: you found, with a tool and a number, the exact function burning CPU on the main thread — not by guessing, by measuring. Note in your `notes/profile-reading.md` how you'd fix it (move `expensiveHash` off the main thread / precompute it once), and that you found it by *profiling*, not by reading the source and guessing.

---

## Acceptance criteria

- [ ] You deployed a **Release** build to a **physical device** (signing succeeded; you can name your device in the Xcode debug bar).
- [ ] You recorded a **Time Profiler** trace while scrolling the heavy list on the device.
- [ ] You identified the function with the highest **self time** on the **main thread** (`expensiveHash` or its inner loop) using the call tree / Heaviest Stack Trace.
- [ ] `notes/profile-reading.md` records: the hottest function, its thread, why main-thread work during scroll is the problem, and how you'd fix it.
- [ ] Build with **0 warnings, 0 errors**.

## What you just proved

You ran the loop the entire week is built on: a Release build on a real device (which tells the truth where the Simulator lies), a Time Profiler capture, and a flame graph read down to the self-time spike — finding the slow function by *measuring*, not guessing. Every later exercise and the mini-project is this loop applied to a real bug (a hang, a hitch) with a fix and a re-measure. You've now done the hard part once: getting onto the device and reading the trace.

---

## Hints (read only if stuck > 10 min)

- **Signing fails on deploy.** Lecture 1, §7's worked flow: team selected? device connected and unlocked and trusted? bundle id unique? Toggle automatic signing off and on; Clean Build Folder (⇧⌘K).
- **The trace shows mostly system frames.** Turn on **"Hide System Libraries"** in the Call Tree options so your code surfaces. Your `expensiveHash` should then dominate self time.
- **`expensiveHash` doesn't show up.** Make sure you built **Release** and actually scrolled (the work only runs as rows render). If you profiled without scrolling, there's nothing to see.
- **The Simulator "is fast enough."** That's exactly the lie. The Simulator runs this on your Mac's CPU. Profile on the *device* — that's the requirement.
