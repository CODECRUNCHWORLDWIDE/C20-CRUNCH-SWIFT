# Week 14 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 60–120 minutes and produces something you can commit to your portfolio and point at in an interview: a demonstrated security fix with the threat model written out.

## Index

1. **[Challenge 1 — Plant a token leak, then lock it down](challenge-01-token-leak-then-lockdown.md)** — store an auth token in `UserDefaults` the way too many shipped apps do, then *prove* it leaks by reading it back out of the app's plaintext preferences plist from the command line. Then move it to the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, prove it's no longer readable that way, and document — in a `THREAT-MODEL.md` — exactly which attacker each step defends against. (~90 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — "here's a token leak I planted, here's the plist I read it out of, and here's the Keychain fix with the threat model" is the kind of concrete security work that lands in code reviews and interviews. The "where does each secret actually live on disk" instinct you build here reappears in Phase III's security week (CryptoKit, the Secure Enclave) and in App Review, which rejects apps that mishandle credentials.
