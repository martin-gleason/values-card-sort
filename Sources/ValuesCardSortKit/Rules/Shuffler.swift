// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// R1 — deck order is a uniform random shuffle, fixed at session start.
///
/// Swift's own `shuffled()` would do, but the rule names Fisher–Yates and the
/// generator is injected so tests can pin an exact order with a seed. A rule
/// that can only be tested statistically is a rule that rots quietly.
public enum Shuffler {
    /// Fisher–Yates, matching `reference/valuescardsort.jsx`: walk from the end,
    /// swap each element with a uniformly chosen element at or before it.
    public static func fisherYates<T>(_ items: [T], using generator: inout some RandomNumberGenerator) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            // Inclusive of i, which is what makes the permutation uniform.
            let j = Int.random(in: 0...i, using: &generator)
            result.swapAt(i, j)
        }
        return result
    }

    public static func fisherYates<T>(_ items: [T]) -> [T] {
        var generator = SystemRandomNumberGenerator()
        return fisherYates(items, using: &generator)
    }
}

/// A seeded, reproducible generator — for tests, and for nothing else.
///
/// SplitMix64: tiny, well-distributed, and fully specified, so a seeded
/// shuffle produces the same order on every machine and every OS version.
/// `SystemRandomNumberGenerator` is what ships; this exists so R1 can be
/// asserted exactly rather than approximately.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
