// Exercise 3 — Custom errors, the `try` family, and `Result`
//
// Goal: Model a custom error enum, write throwing functions against it, exercise
//       `try`, `try?`, and `try!`, and map a throwing outcome into a `Result`,
//       then transform it with map / mapError. This is the exact error-handling
//       skill the syllabus names for the week, drilled in isolation.
//
// Estimated time: 40 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Run it as-is to see the reference behaviour:
//
//          swift exercise-03-errors-and-result.swift
//
//   2. Fill in the bodies marked `// TODO`. Do not change the public surface
//      (the error enum cases, the function signatures, the driver). The driver
//      exercises the code you fill in; if you wire it correctly, the program
//      prints the expected output at the bottom of this file.
//
//   3. Build with warnings as errors:
//
//          swiftc -warnings-as-errors exercise-03-errors-and-result.swift
//
// ACCEPTANCE CRITERIA
//
//   [ ] All TODOs implemented.
//   [ ] The program prints the expected output at the bottom of this file.
//   [ ] `parseAmount` uses `throw` and a `guard`.
//   [ ] You used `try?` to express "I don't care why it failed, treat as nil".
//   [ ] You used `Result { try ... }` to capture a throwing call as a value.
//   [ ] You used `.map` and `.mapError` on a Result.
//   [ ] No `try!` anywhere except the single place the comment authorises it.
//
// Hints are at the bottom. Don't peek for 15 minutes.

import Foundation

// ----------------------------------------------------------------------------
// 1. The custom error domain — a closed set of failure modes.
//    Equatable so tests (and the driver) can compare error values directly.
// ----------------------------------------------------------------------------

enum ParseError: Error, Equatable {
    case empty
    case notANumber(String)
    case negative(Double)
    case tooLarge(Double, limit: Double)
}

// ----------------------------------------------------------------------------
// 2. A throwing function with typed throws over the closed ParseError domain.
//    Parse a money amount: must be non-empty, numeric, non-negative, <= limit.
// ----------------------------------------------------------------------------

let amountLimit = 1_000_000.0

func parseAmount(_ raw: String) throws(ParseError) -> Double {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)

    // TODO: throw .empty if `trimmed` is empty.
    // TODO: parse `trimmed` as a Double; if it isn't a number, throw .notANumber(trimmed).
    // TODO: throw .negative(value) if value < 0.
    // TODO: throw .tooLarge(value, limit: amountLimit) if value > amountLimit.
    // TODO: otherwise return value.
    fatalError("implement parseAmount")
}

// ----------------------------------------------------------------------------
// 3. Exercise the `try` family.
// ----------------------------------------------------------------------------

// 3a. `try` inside do/catch: handle each case precisely.
//     With typed throws, the idiomatic exhaustive form is a single `catch` that
//     binds `error` (typed as ParseError) and `switch`es over it — that switch
//     is checked for exhaustiveness, which is the typed-throws payoff. (Per-case
//     `catch .empty { } catch .notANumber { } ...` is NOT treated as exhaustive,
//     so the compiler would demand a catch-all; the switch form avoids that.)
func classify(_ raw: String) -> String {
    do {
        let value = try parseAmount(raw)
        return "ok: \(String(format: "%.2f", value))"
    } catch {
        switch error {
        case .empty:                      return "rejected: empty"
        case .notANumber(let s):          return "rejected: '\(s)' is not a number"
        case .negative(let v):            return "rejected: negative (\(v))"
        case .tooLarge(let v, let limit): return "rejected: \(v) exceeds limit \(limit)"
        }
    }
}

// 3b. `try?` — "I don't care why; a bad input is just nil."
func amountOrNil(_ raw: String) -> Double? {
    // TODO: return the parsed amount, or nil if it threw. One line with try?.
    fatalError("implement amountOrNil")
}

// 3c. `try!` — authorised exactly once: a literal we KNOW is valid.
//     If this ever throws, the program SHOULD crash, because the bug is in our
//     own source, not in user input.
let knownGood: Double = try! parseAmount("42.50")

// ----------------------------------------------------------------------------
// 4. Map throwing outcomes into Result, then transform.
// ----------------------------------------------------------------------------

// 4a. Capture a throwing call as a Result value (success OR the thrown error).
func parseResult(_ raw: String) -> Result<Double, ParseError> {
    // TODO: use `Result { try parseAmount(raw) }`.
    //       Note: `Result { ... }` produces Result<Double, any Error>; map the
    //       error back to ParseError with `.mapError { $0 as! ParseError }`
    //       — authorised here because parseAmount can only throw ParseError.
    fatalError("implement parseResult")
}

// 4b. Transform a Result without unwrapping: cents = dollars * 100.
func centsResult(_ raw: String) -> Result<Int, ParseError> {
    // TODO: parseResult(raw).map { Int(($0 * 100).rounded()) }
    fatalError("implement centsResult")
}

// 4c. Rewrite the failure into a user-facing message via mapError-to-String.
//     (mapError must return an Error type, so we wrap a String in a small enum.)
enum DisplayError: Error, Equatable { case message(String) }

func displayResult(_ raw: String) -> Result<Int, DisplayError> {
    centsResult(raw).mapError { parseError in
        switch parseError {
        case .empty:               return .message("Please enter an amount.")
        case .notANumber(let s):   return .message("'\(s)' isn't a number.")
        case .negative:            return .message("Amount can't be negative.")
        case .tooLarge(_, let lim): return .message("Amount can't exceed \(Int(lim)).")
        }
    }
}

// ----------------------------------------------------------------------------
// Driver — DO NOT CHANGE.
// ----------------------------------------------------------------------------

print("known good (try!): \(String(format: "%.2f", knownGood))")
print()

let inputs = ["10.00", "", "twelve", "-3", "2000000", "  99.50  "]

print("classify (do/catch):")
for input in inputs {
    print("  '\(input)' -> \(classify(input))")
}
print()

print("amountOrNil (try?):")
for input in inputs {
    let v = amountOrNil(input)
    print("  '\(input)' -> \(v.map { String(format: "%.2f", $0) } ?? "nil")")
}
print()

print("centsResult (Result.map):")
for input in inputs {
    switch centsResult(input) {
    case .success(let cents): print("  '\(input)' -> \(cents)c")
    case .failure(let err):   print("  '\(input)' -> error \(err)")
    }
}
print()

print("displayResult (Result.mapError):")
for input in inputs {
    switch displayResult(input) {
    case .success(let cents): print("  '\(input)' -> \(cents)c")
    case .failure(.message(let m)): print("  '\(input)' -> \"\(m)\"")
    }
}

// ----------------------------------------------------------------------------
// Expected output (yours should match):
// ----------------------------------------------------------------------------
//
// known good (try!): 42.50
//
// classify (do/catch):
//   '10.00' -> ok: 10.00
//   '' -> rejected: empty
//   'twelve' -> rejected: 'twelve' is not a number
//   '-3' -> rejected: negative (-3.0)
//   '2000000' -> rejected: 2000000.0 exceeds limit 1000000.0
//   '  99.50  ' -> ok: 99.50
//
// amountOrNil (try?):
//   '10.00' -> 10.00
//   '' -> nil
//   'twelve' -> nil
//   '-3' -> nil
//   '2000000' -> nil
//   '  99.50  ' -> 99.50
//
// centsResult (Result.map):
//   '10.00' -> 1000c
//   '' -> error empty
//   'twelve' -> error notANumber("twelve")
//   '-3' -> error negative(-3.0)
//   '2000000' -> error tooLarge(2000000.0, limit: 1000000.0)
//   '  99.50  ' -> 9950c
//
// displayResult (Result.mapError):
//   '10.00' -> 1000c
//   '' -> "Please enter an amount."
//   'twelve' -> "'twelve' isn't a number."
//   '-3' -> "Amount can't be negative."
//   '2000000' -> "Amount can't exceed 1000000."
//   '  99.50  ' -> 9950c
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// parseAmount:
//   guard !trimmed.isEmpty else { throw .empty }
//   guard let value = Double(trimmed) else { throw .notANumber(trimmed) }
//   guard value >= 0 else { throw .negative(value) }
//   guard value <= amountLimit else { throw .tooLarge(value, limit: amountLimit) }
//   return value
//
// amountOrNil:
//   try? parseAmount(raw)
//
// parseResult:
//   Result { try parseAmount(raw) }.mapError { $0 as! ParseError }
//
// centsResult:
//   parseResult(raw).map { Int(($0 * 100).rounded()) }
//
// ----------------------------------------------------------------------------
