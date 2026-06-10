# Week 18 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 90–150 minutes and produces something you can commit to your portfolio and point at in an interview: a worked walkthrough of the three subscription edge cases that separate a working purchase from a working business.

## Index

1. **[Challenge 1 — The subscription edge cases: refund, downgrade, billing retry](challenge-01-subscription-edge-cases.md)** — reproduce a refund, a plan downgrade, and a billing-retry recovery in the StoreKit sandbox / `.storekit` transaction manager, and prove that your client gate AND your server entitlement reflect each transition correctly and promptly. You produce a table of the three transitions with the expected vs observed behaviour on both client and server, plus the App Store Server Notification that drove each. (~120 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — "I drove a refund, a downgrade, and a billing-retry recovery and proved my entitlement reflected each within minutes, here's the notification table" is exactly the kind of concrete subscription competence that lands in code reviews and interviews, because it's the part most apps get *wrong*. This is also direct preparation for the Phase IV capstone's **subscription edge-cases chaos drill** — you're doing a rehearsal of it here.
