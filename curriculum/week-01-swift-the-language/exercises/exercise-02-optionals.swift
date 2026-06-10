// Exercise 2 — Optionals
//
// Goal: Practice every idiomatic way to handle a Swift Optional — if let,
//       guard let, optional chaining, and nil-coalescing — and see a
//       force-unwrap-heavy snippet refactored into crash-safe code.
//
// Estimated time: 35 minutes.
//
// HOW TO RUN THIS FILE
//
//   swift exercise-02-optionals.swift
//
// (Or compile first: swiftc exercise-02-optionals.swift -o ex2 && ./ex2)
//
// This file is COMPLETE and CORRECT — it runs as written and prints the
// expected output at the bottom. Read it top to bottom, run it, then do the
// "YOUR TURN" drill at the very end (a reference solution is in the hints).
//
// WHAT TO INTERNALISE
//
//   - There is no `null` in Swift. "No value" is `nil`, and only an Optional
//     can be nil.
//   - Reach for guard let, then if let, then ??, then ?. — in that order —
//     before you ever consider the force-unwrap `!`.
//   - Every `!` is a potential crash. The crash-safe rewrite uses none.

import Foundation

// ----------------------------------------------------------------------------
// 1. if let — bind and use in a scope
// ----------------------------------------------------------------------------

func describeAge(_ raw: String) -> String {
    // Int(raw) returns Int? — the conversion can fail.
    if let age = Int(raw) {
        return "Parsed age \(age)."
    } else {
        return "Could not parse '\(raw)' as an age."
    }
}

// ----------------------------------------------------------------------------
// 2. guard let — unwrap-or-leave, keeping the happy path un-indented
// ----------------------------------------------------------------------------

func greet(name maybeName: String?) -> String {
    guard let name = maybeName, !name.isEmpty else {
        return "Refusing to greet an empty name."
    }
    // `name` is a non-optional, non-empty String for the rest of the function.
    return "Hello, \(name)!"
}

// ----------------------------------------------------------------------------
// 3. nil-coalescing ?? — supply a default
// ----------------------------------------------------------------------------

func displayName(_ nickname: String?) -> String {
    nickname ?? "(anonymous)"
}

// ----------------------------------------------------------------------------
// 4. Optional chaining ?. — reach through, short-circuit on nil
// ----------------------------------------------------------------------------

struct User {
    let profile: Profile?
}

struct Profile {
    let bio: String?
}

func bioLength(of user: User?) -> Int {
    // Each ?. short-circuits to nil if any link is nil; ?? supplies a default.
    user?.profile?.bio?.count ?? 0
}

// ----------------------------------------------------------------------------
// 5. The refactor: a force-unwrap-heavy snippet, made crash-safe
// ----------------------------------------------------------------------------

// BEFORE (do NOT ship this — every `!` is a crash waiting for bad input):
//
//   func parsePointBAD(_ csv: String) -> (Int, Int) {
//       let parts = csv.split(separator: ",")
//       let x = Int(parts[0])!      // 💥 crashes if parts is empty or not a number
//       let y = Int(parts[1])!      // 💥 crashes if there's no second field
//       return (x, y)
//   }
//
// AFTER — crash-safe, returns an Optional tuple, zero `!`:

func parsePoint(_ csv: String) -> (x: Int, y: Int)? {
    let parts = csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 2,
          let x = Int(parts[0]),
          let y = Int(parts[1]) else {
        return nil
    }
    return (x, y)
}

// ----------------------------------------------------------------------------
// Driver — prints the expected output
// ----------------------------------------------------------------------------

print("== 1. if let ==")
print(describeAge("42"))
print(describeAge("forty"))

print("== 2. guard let ==")
print(greet(name: "Ada"))
print(greet(name: nil))
print(greet(name: ""))

print("== 3. nil-coalescing ==")
print(displayName("ada"))
print(displayName(nil))

print("== 4. optional chaining ==")
let withBio = User(profile: Profile(bio: "Wrote the first algorithm."))
let noBio   = User(profile: Profile(bio: nil))
let noProfile = User(profile: nil)
print("withBio:   \(bioLength(of: withBio))")
print("noBio:     \(bioLength(of: noBio))")
print("noProfile: \(bioLength(of: noProfile))")
print("nilUser:   \(bioLength(of: nil))")

print("== 5. crash-safe parse ==")
print("'3,4'      -> \(String(describing: parsePoint("3,4")))")
print("'3'        -> \(String(describing: parsePoint("3")))")
print("'a,b'      -> \(String(describing: parsePoint("a,b")))")
print("' 7 , 8 '  -> \(String(describing: parsePoint(" 7 , 8 ")))")

// ----------------------------------------------------------------------------
// YOUR TURN
// ----------------------------------------------------------------------------
//
// Below is a fresh, intentionally fragile function. Rewrite it to be crash-safe
// WITHOUT any force-unwrap `!`. It should return the first email's domain
// (the part after "@") for the first user that HAS an email, or "(none)".
//
//   struct Account { let email: String? }
//
//   func firstDomainBAD(_ accounts: [Account]) -> String {
//       let withEmail = accounts.first { $0.email != nil }!   // 💥
//       let email = withEmail.email!                          // 💥
//       return String(email.split(separator: "@")[1])         // 💥 if no "@"
//   }
//
// Write `firstDomain(_:)` so that:
//   firstDomain([Account(email: nil), Account(email: "ada@swift.org")]) == "swift.org"
//   firstDomain([Account(email: nil)])                                  == "(none)"
//   firstDomain([])                                                     == "(none)"
//   firstDomain([Account(email: "broken")])                             == "(none)"   // no "@"
//
// A reference solution is in the hints at the bottom. Try it yourself first.

struct Account { let email: String? }

func firstDomain(_ accounts: [Account]) -> String {
    for account in accounts {
        if let email = account.email,
           let domain = email.split(separator: "@", maxSplits: 1).dropFirst().first,
           !domain.isEmpty {
            return String(domain)
        }
    }
    return "(none)"
}

print("== YOUR TURN ==")
print(firstDomain([Account(email: nil), Account(email: "ada@swift.org")]))
print(firstDomain([Account(email: nil)]))
print(firstDomain([]))
print(firstDomain([Account(email: "broken")]))

// ----------------------------------------------------------------------------
// Expected output
// ----------------------------------------------------------------------------
//
// == 1. if let ==
// Parsed age 42.
// Could not parse 'forty' as an age.
// == 2. guard let ==
// Hello, Ada!
// Refusing to greet an empty name.
// Refusing to greet an empty name.
// == 3. nil-coalescing ==
// ada
// (anonymous)
// == 4. optional chaining ==
// withBio:   26
// noBio:     0
// noProfile: 0
// nilUser:   0
// == 5. crash-safe parse ==
// '3,4'      -> Optional((x: 3, y: 4))
// '3'        -> nil
// 'a,b'      -> nil
// ' 7 , 8 '  -> Optional((x: 7, y: 8))
// == YOUR TURN ==
// swift.org
// (none)
// (none)
// (none)
//
// ----------------------------------------------------------------------------
// ACCEPTANCE CRITERIA
// ----------------------------------------------------------------------------
//
//   [ ] `swift exercise-02-optionals.swift` runs with no errors or warnings.
//   [ ] Output matches the expected output above.
//   [ ] Your `firstDomain` contains ZERO force-unwrap `!` operators.
//       (`!=` and the logical-not `!` are fine; we mean the postfix unwrap `!`.)
//   [ ] You can explain why `parsePoint` returns `(x: Int, y: Int)?` and not a
//       plain tuple.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck >15 min)
// ----------------------------------------------------------------------------
//
// Reference solution for firstDomain, written with guard let instead of if let:
//
//   func firstDomain(_ accounts: [Account]) -> String {
//       for account in accounts {
//           guard let email = account.email else { continue }
//           let halves = email.split(separator: "@", maxSplits: 1)
//           guard halves.count == 2, !halves[1].isEmpty else { continue }
//           return String(halves[1])
//       }
//       return "(none)"
//   }
//
// Why parsePoint returns an Optional tuple: the input may not contain two
// integers separated by a comma, so the function must be able to say "no valid
// point here." An Optional is exactly that: a return type that can be absent.
// Returning a plain `(Int, Int)` would force a sentinel value or a force-unwrap.
//
// ----------------------------------------------------------------------------
