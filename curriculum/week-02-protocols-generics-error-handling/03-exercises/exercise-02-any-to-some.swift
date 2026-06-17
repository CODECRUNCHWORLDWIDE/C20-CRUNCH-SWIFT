// Exercise 2 — Refactor `any` to `some`
//
// Goal: Take an API written entirely with `any` (existentials) and move each
//       declaration to `some` (opaque) — or to a named generic — where that is
//       the better choice, documenting WHY in a one-line comment per change.
//       Leave `any` exactly where heterogeneity genuinely requires it.
//
// Estimated time: 40 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Run it as-is first to see it work (it compiles and prints output):
//
//          swift exercise-02-any-to-some.swift
//
//   2. Then perform the refactor described under each `// REFACTOR:` marker.
//      The behaviour and the printed output MUST stay identical — you are
//      changing the TYPE annotations, not the logic.
//
//   3. After each change, re-run. The expected output is at the bottom of the
//      file and must not change.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Every `// REFACTOR:` marker is addressed with the right tool
//       (some / named generic / leave-as-any) and a one-line justification.
//   [ ] The program still prints the expected output at the bottom of this file.
//   [ ] Exactly ONE `any` remains in the file after the refactor (the zoo),
//       and you can explain in one sentence why it cannot be `some`.
//   [ ] No warnings: `swiftc -warnings-as-errors exercise-02-any-to-some.swift`.
//
// The hints at the bottom show the intended final shape — don't peek for 15 min.

import Foundation

// ----------------------------------------------------------------------------
// Domain protocol (no associated type — so `any` is legal but often wasteful)
// ----------------------------------------------------------------------------

protocol Shape {
    var area: Double { get }
    var name: String { get }
}

struct Circle: Shape {
    let radius: Double
    var area: Double { .pi * radius * radius }
    var name: String { "circle" }
}

struct Square: Shape {
    let side: Double
    var area: Double { side * side }
    var name: String { "square" }
}

// ----------------------------------------------------------------------------
// The API to refactor. Everything is `any` right now. Most of it shouldn't be.
// ----------------------------------------------------------------------------

// REFACTOR 1: This factory ALWAYS returns the same concrete type (Circle).
//   It does not need to return a boxed existential. Move the return to `some`.
//   Why some: one concrete type, hidden, zero cost, no heap box.
func makeUnitCircle() -> any Shape {
    Circle(radius: 1)
}

// REFACTOR 2: This takes one shape and uses its type once. A parameter used
//   once is a textbook `some` (lightweight generic). Move the parameter to `some`.
//   Why some: avoids boxing the argument; the call is specialised and inlined.
func describe(_ shape: any Shape) -> String {
    "\(shape.name) with area \(String(format: "%.2f", shape.area))"
}

// REFACTOR 3: This returns the SAME shape it was handed (scaled). The return
//   type is RELATED to the input type — you want a NAMED GENERIC so the caller
//   gets back the concrete type they passed in, not an erased box.
//   (Circle scaled stays a Circle; Square scaled stays a Square.)
//   Why named generic: it ties the return type to the parameter type.
func scaled(_ shape: any Shape, by factor: Double) -> any Shape {
    // For the drill we model "scale" as building a new shape of the same kind.
    // After refactor this returns S, the same concrete type as the input.
    switch shape {
    case let c as Circle: return Circle(radius: c.radius * factor)
    case let s as Square: return Square(side: s.side * factor)
    default: return shape
    }
}

// REFACTOR 4 (LEAVE AS-IS): A heterogeneous collection genuinely needs `any`.
//   Different concrete types (Circle AND Square) live in one array. `some`
//   would force every element to the SAME type, which is not what we want.
//   Keep this `any`. Add a comment saying why.
func totalArea(of shapes: [any Shape]) -> Double {
    shapes.reduce(0) { $0 + $1.area }
}

// ----------------------------------------------------------------------------
// Driver — DO NOT CHANGE. If your refactor is correct the output is identical.
// ----------------------------------------------------------------------------

let unit = makeUnitCircle()
print(describe(unit))

let bigCircle = scaled(Circle(radius: 2), by: 3)
print(describe(bigCircle))

let bigSquare = scaled(Square(side: 2), by: 2.5)
print(describe(bigSquare))

// The zoo: deliberately heterogeneous. This NEEDS `any`.
let zoo: [any Shape] = [Circle(radius: 1), Square(side: 2), Circle(radius: 3)]
print("shapes in zoo: \(zoo.count)")
print("total area: \(String(format: "%.2f", totalArea(of: zoo)))")

// ----------------------------------------------------------------------------
// Expected output (must be identical before and after your refactor):
// ----------------------------------------------------------------------------
//
// circle with area 3.14
// circle with area 113.10
// square with area 25.00
// shapes in zoo: 3
// total area: 35.42
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// REFACTOR 1:
//   func makeUnitCircle() -> some Shape { Circle(radius: 1) }
//
// REFACTOR 2:
//   func describe(_ shape: some Shape) -> String { ... }
//   // some Shape == <S: Shape>(_ shape: S); used once, so the unnamed form is cleaner.
//
// REFACTOR 3:
//   func scaled<S: Shape>(_ shape: S, by factor: Double) -> S { ... }
//   // BUT: to build "a new S of the same kind" generically you need a protocol
//   // requirement to construct/scale. The simplest correct refactor adds a
//   // `func scaled(by:) -> Self` requirement to Shape and gives each type an
//   // implementation, then `scaled` becomes:
//   //
//   //   func scaled(_ shape: some Shape, by factor: Double) -> some Shape {
//   //       shape.scaled(by: factor)   // returns Self — preserved as opaque
//   //   }
//   //
//   // That is the idiomatic Swift answer: push the "same type back" requirement
//   // into the protocol via `Self`, then `some Shape` preserves it for free.
//   // (Add `func scaled(by factor: Double) -> Self` to `Shape` and implement it
//   //  on Circle and Square. Delete the as-casts entirely.)
//
// REFACTOR 4:
//   Leave `[any Shape]`. A heterogeneous array of different concrete types is
//   exactly what existentials are for. `some Shape` would pin every element to
//   one type. This is the one `any` that should survive.
//
// ----------------------------------------------------------------------------
