# Week 17 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 60–120 minutes and produces something you can commit to your portfolio and point at in an interview: a demonstrated MITM attack, then the pinning that defeats it, with evidence on both sides.

## Index

1. **[Challenge 1 — MITM your own app, then pin it shut](challenge-01-mitm-then-pin.md)** — stand up `mitmproxy` as a man-in-the-middle, install its CA so the Simulator trusts it, watch the proxy read (and rewrite) your unpinned HTTPS traffic, then add SPKI pinning and prove the *same* proxy is now locked out. You produce a "before" capture (the proxy reading plaintext) and an "after" capture (the connection refused), plus a short writeup of what pinning changed and why. (~90 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — "I demonstrated a working MITM against my own app and then proved my pinning shut it out, here's the proxy log before and after" is the kind of concrete, adversarial evidence that lands in security reviews and interviews. The "see the attack, then defeat it" instinct you build here is exactly what Phase IV's chaos-drill week asks for, just applied to a different failure.
