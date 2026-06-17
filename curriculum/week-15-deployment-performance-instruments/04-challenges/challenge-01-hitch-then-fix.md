# Challenge 1 — Plant a scroll hitch, then fix it (with traces)

**Time.** 60–120 minutes.
**Deliverable.** A `PERF.md` with two hitch-ratio numbers (before/after), two Instruments screenshots (Animation Hitches), and the refactored code, committed to your Week 15 repo. **Requires a physical device** (ideally a ProMotion one — the 8.33 ms budget makes the hitch more visible) and a paid account.

## The premise

A scroll hitch is the most common "this app feels cheap" bug, and the most satisfying to fix because the fix is dramatic and the proof is a clean number. The classic cause is doing expensive work — most often a full-resolution image decode — synchronously on the render-commit path, so the frames where new cells appear blow the budget. The skill this challenge builds is not "know hitches exist." It's **plant one, measure the hitch ratio on a real device, fix the render path, and prove the fix with a before/after trace.**

You will build an image list the wrong way, measure it, fix it, and measure again. The grade is the gap between the two hitch ratios and your explanation of the render-path cause.

## What to build

Start from any SwiftUI app. You need a scrolling list of cells, each showing an image large enough that decoding it is expensive.

### Step 1 — Seed large images

Generate (or bundle) a few large images — say 4000×4000 px — and a model with many rows referencing them. Even a handful of distinct large images reused across hundreds of rows will hitch, because the decode happens per cell appearance.

```swift
struct Photo: Identifiable {
    let id = UUID()
    let data: Data   // a LARGE (multi-MB) image's bytes
}

// Seed ~500 rows reusing a few big images.
func seedPhotos(from bigImages: [Data]) -> [Photo] {
    (0..<500).map { Photo(data: bigImages[$0 % bigImages.count]) }
}
```

### Step 2 — Plant the hitch (the WRONG cell)

Decode the full-resolution image synchronously, on the main thread, as each cell renders:

```swift
struct PhotoRowBad: View {
    let photo: Photo
    var body: some View {
        HStack {
            // UIImage(data:) DECODES THE FULL 4000px IMAGE on the main thread,
            // on the scroll path, every time this cell is created. THE HITCH.
            Image(uiImage: UIImage(data: photo.data)!)
                .resizable()
                .frame(width: 60, height: 60)   // displayed tiny, but decoded huge
            Text(photo.id.uuidString.prefix(8))
        }
    }
}
```

Note the waste: the image is *displayed* at 60×60 but *decoded* at 4000×4000 — megabytes of pixels processed on the UI thread to show a thumbnail. Run it on the device and scroll fast. It stutters.

### Step 3 — Measure the hitch (the "before")

1. **Product ▸ Profile** (⌘I) → **Animation Hitches** template (or the SwiftUI template with hitches).
2. Record, then scroll the list fast for ~10 seconds on the device.
3. Read the **hitch time ratio** (ms of hitch per second of scrolling). On a big-image list this is typically tens of ms/s — well above the smooth threshold.
4. Screenshot the trace showing the over-budget frames. Record the number in `PERF.md`.

### Step 4 — Fix the render path (the RIGHT cell)

Move the decode off the main thread and **downsample** to the displayed size, so the scroll path is cheap. Use ImageIO to decode-and-downsample in one step off-main, and cache the result:

```swift
import ImageIO
import UIKit

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [UUID: UIImage] = [:]

    /// Decode-and-downsample OFF the main thread, to the displayed pixel size.
    func thumbnail(for photo: Photo, maxPixel: CGFloat) -> UIImage? {
        if let cached = cache[photo.id] { return cached }
        guard let source = CGImageSourceCreateWithData(photo.data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,   // downsample to display size
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cg)
        cache[photo.id] = image
        return image
    }
}

struct PhotoRowGood: View {
    let photo: Photo
    @State private var thumb: UIImage?
    var body: some View {
        HStack {
            Group {
                if let thumb { Image(uiImage: thumb).resizable() }
                else { Color.secondary.opacity(0.2) }
            }
            .frame(width: 60, height: 60)
            Text(photo.id.uuidString.prefix(8))
        }
        .task {
            // Off-main decode+downsample; only the small thumbnail crosses back.
            thumb = await ThumbnailCache.shared.thumbnail(for: photo, maxPixel: 120)  // 60pt @2x
        }
    }
}
```

Now the scroll path does *no* synchronous decode — the cell shows a placeholder, an off-main task decodes a small thumbnail, and the cache means each image decodes once. The frames stay under budget.

### Step 5 — Measure again (the "after")

Re-profile with Animation Hitches, scroll the same way, and read the new hitch ratio. It should be a small fraction of the before number. Screenshot the "after" trace showing in-budget frames. Record the number and the speedup in `PERF.md`.

## Acceptance criteria

- [ ] A list with **≥ 500 rows** of large (multi-MB) images.
- [ ] `PhotoRowBad` (synchronous full-res decode on the scroll path) and `PhotoRowGood` (off-main decode + downsample + cache) both exist.
- [ ] `PERF.md` records: the **before** hitch ratio, the **after** hitch ratio, the speedup, and the **device** (model + refresh rate) you measured on.
- [ ] One Animation Hitches screenshot of the "before" trace (over-budget frames) and one of the "after" (in-budget).
- [ ] A 3–5 sentence explanation of **why** the fix works — render path kept cheap, decode moved off-main, downsampled to the displayed size, cached so each image decodes once — in your own words.
- [ ] The fix uses real off-main concurrency (an actor / `.task`), not a suppressed warning.
- [ ] Build with **0 warnings**.

## What "great" looks like

A weak submission says "I made the scroll smoother." A great submission says:

> On an iPhone 14 Pro (120 Hz, 8.33 ms budget) Release build, the photo list scrolled with a hitch ratio of 36 ms/s; the Animation Hitches trace showed every cell-appearance frame blowing the budget, with the time spent in a synchronous `UIImage(data:)` decoding 4000×4000 pixels on the main thread to display a 60-point thumbnail. After moving the decode off-main with ImageIO's `CGImageSourceCreateThumbnailAtIndex`, downsampling to 120 px (60 pt @2x), and caching per photo, the hitch ratio dropped to 2 ms/s with no over-budget frames — roughly an 18× improvement. The win isn't "decode faster," it's "don't decode on the render path at all, and don't decode 4000px to show 60pt."

Quantified, explained, and honest about *which* change mattered (off the render path + downsample, not "optimize the decode"). That's the senior-engineer answer.

## Where this reappears

The "keep the render path cheap, measure the hitch ratio" instinct is exactly what Phase IV's polish week and the App Review prep build on — a janky scroll is one of the most common reasons a build feels unfinished. And the off-main-decode pattern is the same shape as the off-main-fetch pattern from exercise 2's hang fix: expensive work belongs off the main thread, whether it's a computation, a fetch, or an image decode. Same disease, same cure.
