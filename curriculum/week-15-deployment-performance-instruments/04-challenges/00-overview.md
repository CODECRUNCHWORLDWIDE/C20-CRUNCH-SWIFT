# Week 15 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 60–120 minutes and produces something you can commit to your portfolio and point at in an interview: a measured scroll-performance fix with before/after Instruments traces.

## Index

1. **[Challenge 1 — Plant a scroll hitch, then fix it (with traces)](./challenge-01-hitch-then-fix.md)** — build a list that decodes a full-resolution image synchronously on the scroll path, measure the hitch ratio in the Animation Hitches instrument on a real device, fix it by moving the decode off-main and downsampling, and document the before/after with two traces and a number. (~90 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — "the notes list had a 38 ms/s hitch ratio from a synchronous image decode on the scroll path; after moving the decode off-main and downsampling to the cell size, it's 2 ms/s, here are both traces" is the kind of concrete, quantified win that lands in code reviews and interviews. The measure-fix-measure discipline you build here is the same one Phase IV's polish and the App Review prep depend on — a janky scroll is one of the most common reasons a build *feels* unfinished, and one of the easiest to fix once you can see it in a trace.
