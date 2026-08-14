// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

/// Ways the deck contract can be violated (SPEC §4).
public enum DeckError: Error, Equatable, CustomStringConvertible {
    case resourceMissing
    case malformed(String)
    case countMismatch(declared: Int, actual: Int)
    case nonContiguousIDs
    case duplicateIDs([Int])
    case duplicateNames([String])
    case payloadHashMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .resourceMissing:
            "deck.v1.json is not in the bundle. The app cannot run without the instrument."
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

    /// SHA-256 of the canonical card payload of `deck.v1.json`.
    ///
    /// This is deliberately *not* a hash of the file. Chore C1's sign-off edits
    /// `instrument.verification` inside the file, which would break a file
    /// hash while changing no card — so the file hash is pinned in SPEC §4 and
    /// `scripts/check-deck.sh`, and this payload hash is what the running app
    /// enforces. Card drift fails here forever; metadata edits do not.
    ///
    /// See ``canonicalPayload(of:)`` for the serialization.
    public static let payloadSHA256 = "10a4c3938226a83f72724809d91f817051d29164f517554b5b3ac6f6775c25d4"

    /// The canonical, language-neutral serialization the payload hash covers.
    ///
    /// Separator-delimited rather than JSON so that this Swift code and
    /// `scripts/check_deck.py` cannot disagree about key ordering or string
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

/// Loads and validates the bundled deck.
///
/// Validation is not optional and not a test-only path: a deck that fails the
/// contract must not reach a user, because the whole claim of this app is that
/// it is faithful to the printed instrument.
public enum DeckLoader {
    /// Loads `deck.v1.json` from the package bundle.
    public static func load() throws -> Deck {
        guard let url = Bundle.module.url(forResource: "deck.v1", withExtension: "json") else {
            throw DeckError.resourceMissing
        }
        return try load(contentsOf: url)
    }

    public static func load(contentsOf url: URL) throws -> Deck {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DeckError.resourceMissing
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> Deck {
        let deck: Deck
        do {
            deck = try JSONDecoder().decode(Deck.self, from: data)
        } catch {
            throw DeckError.malformed(String(describing: error))
        }
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
