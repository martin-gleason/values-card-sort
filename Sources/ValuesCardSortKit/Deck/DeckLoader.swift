// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

/// Ways the deck contract can be violated (SPEC §4).
public enum DeckError: Error, Equatable, CustomStringConvertible {
    case malformed(String)
    case countMismatch(declared: Int, actual: Int)
    case nonContiguousIDs
    case duplicateIDs([Int])
    case duplicateNames([String])
    case payloadHashMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .malformed(let detail):
            "deck.v1.json is malformed: \(detail)"
        case .countMismatch(let declared, let actual):
            "cardCount says \(declared) but the file carries \(actual) cards."
        case .nonContiguousIDs:
            "card ids are not contiguous 1…\(Deck.expectedCardCount) in file order."
        case .duplicateIDs(let ids):
            "duplicate card ids: \(ids.map(String.init).joined(separator: ", "))"
        case .duplicateNames(let names):
            "duplicate card names: \(names.joined(separator: ", "))"
        case .payloadHashMismatch(let expected, let actual):
            """
            the 83 cards have drifted.
              expected \(expected)
              actual   \(actual)
            The deck is immutable (SPEC §4): a change is a new versioned file \
            plus a ratified spec delta.
            """
        }
    }
}

extension Deck {
    /// The instrument has 83 numbered cards (SPEC §2, verified against source).
    public static let expectedCardCount = 83

    /// SHA-256 of the canonical card payload (SPEC §4).
    ///
    /// **Hand-pinned here on purpose, and not emitted by the generator.** If
    /// this lived in `Deck.v1.generated.swift`, altering a card's text and the
    /// hash guarding it would be one edit to one file. Keeping it in
    /// hand-written source means tampering has to touch two files that a
    /// reviewer reads differently — and the same constant is pinned a third
    /// time in `scripts/check_deck.py` and a fourth in SPEC §4.
    ///
    /// Re-checked at runtime by ``DeckLoader/validate(_:)``, so a patched
    /// binary fails too and the app refuses to run a sort.
    public static let payloadSHA256 = "10a4c3938226a83f72724809d91f817051d29164f517554b5b3ac6f6775c25d4"

    /// The canonical, language-neutral serialization the payload hash covers.
    ///
    /// Separator-delimited rather than JSON so that this Swift code and
    /// `scripts/generate_deck.py` cannot disagree about key ordering or string
    /// escaping — the two must produce byte-identical output or the pinned
    /// constant is meaningless. Deck v1 is pure ASCII, so the unit (U+001F)
    /// and record (U+001E) separators cannot collide with card data.
    public static func canonicalPayload(of cards: [ValueCard]) -> String {
        let unit = "\u{001F}"
        let record = "\u{001E}"
        return cards
            .map { "\($0.id)\(unit)\($0.name)\(unit)\($0.descriptor)" }
            .joined(separator: record)
    }
}

/// Provides the compiled deck, validated.
///
/// There is no file to load. The deck is generated into Swift source from
/// `data/deck.v1.json` and compiled into the binary, so the app ships no
/// parsable copy of the instrument text (SPEC §4, ratified 2026-08-14). The
/// name is kept because "load the deck" is still what callers mean.
///
/// Validation is not optional and not a test-only path: a deck that fails the
/// contract must not reach a user, because the whole claim of this app is that
/// it is faithful to the printed instrument. Re-checking a compiled constant
/// looks redundant and is not — it catches a patched binary, which is the one
/// tampering route that compiling the deck in does not by itself close.
public enum DeckLoader {
    public static func load() throws -> Deck {
        try validated(Deck.v1)
    }

    /// Validates any deck. Used by the tests to prove the checks reject the
    /// decks they are supposed to reject.
    @discardableResult
    public static func validated(_ deck: Deck) throws -> Deck {
        try validate(deck)
        return deck
    }

    /// Asserts the deck contract (SPEC §4) — the same facts
    /// `scripts/check-deck.sh` asserts about the file on disk, re-asserted here
    /// about the data the app actually loaded. Both are needed: the script
    /// catches a bad file, this catches a good file that never reached the
    /// bundle.
    public static func validate(_ deck: Deck) throws {
        guard deck.cardCount == deck.cards.count else {
            throw DeckError.countMismatch(declared: deck.cardCount, actual: deck.cards.count)
        }
        guard deck.cards.count == Deck.expectedCardCount else {
            throw DeckError.countMismatch(declared: Deck.expectedCardCount, actual: deck.cards.count)
        }

        let ids = deck.cards.map(\.id)
        let duplicateIDs = ids.duplicates()
        guard duplicateIDs.isEmpty else { throw DeckError.duplicateIDs(duplicateIDs.sorted()) }
        guard ids == Array(1...Deck.expectedCardCount) else { throw DeckError.nonContiguousIDs }

        let duplicateNames = deck.cards.map(\.name).duplicates()
        guard duplicateNames.isEmpty else { throw DeckError.duplicateNames(duplicateNames.sorted()) }

        let actual = sha256(Deck.canonicalPayload(of: deck.cards))
        guard actual == Deck.payloadSHA256 else {
            throw DeckError.payloadHashMismatch(expected: Deck.payloadSHA256, actual: actual)
        }
    }

    static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

extension Array where Element: Hashable {
    /// Elements that appear more than once, each reported once.
    fileprivate func duplicates() -> [Element] {
        var seen: Set<Element> = []
        var dupes: Set<Element> = []
        for element in self where !seen.insert(element).inserted {
            dupes.insert(element)
        }
        return Array(dupes)
    }
}
