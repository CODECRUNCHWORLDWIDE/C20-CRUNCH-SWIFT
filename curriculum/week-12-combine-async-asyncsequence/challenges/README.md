# Week 12 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 90–120 minutes and produces something you can commit to your portfolio and point at in an interview: the same debounced search built two ways, with the latency and dropped-search numbers that justify your choice.

## Index

1. **[Challenge 1 — Debounce two ways, measured](challenge-01-debounce-two-ways-measured.md)** — implement search-as-you-type debounce both with Combine (`.debounce`) and with `AsyncStream` (hand-rolled), instrument both to count how many searches *actually fired* for a simulated fast typist and the keystroke→search latency, prove they drop the same intermediate keystrokes, and write the decision note that picks one for "Notes v1." (~100 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — and "here's the same debounce in Combine and AsyncStream with the latency numbers and the reason I shipped one" is exactly the concrete, quantified answer that lands when an interviewer asks "Combine or async/await?" The measure-then-decide instinct you build here is the spine of the decision matrix, and it reappears the moment Phase III points these streams at a real network.
