// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One card from the printed instrument.
///
/// The `id` is the card's 1-based position in the deck as published, not an
/// arbitrary key — it is how a card is cited back to the source document, so
/// it is stable for the life of a deck version (SPEC §4).
public struct ValueCard: Hashable, Sendable, Identifiable {
    /// 1…83, contiguous, matching the printed instrument's numbering.
    public let id: Int
    /// The value name as printed: uppercase, e.g. `"SELF-KNOWLEDGE"`.
    public let name: String
    /// The gloss beneath the name, e.g. `"to have a deep and honest understanding of myself"`.
    public let descriptor: String

    public init(id: Int, name: String, descriptor: String) {
        self.id = id
        self.name = name
        self.descriptor = descriptor
    }
}

/// The instrument's provenance, carried in the deck file so attribution
/// travels with the data rather than being retyped in the UI (SPEC §2, §8).
public struct Instrument: Hashable, Sendable {
    public init(
        title: String, authors: String, institution: String, year: Int,
        copyright: String, sources: [String], verification: String
    ) {
        self.title = title
        self.authors = authors
        self.institution = institution
        self.year = year
        self.copyright = copyright
        self.sources = sources
        self.verification = verification
    }

    public let title: String
    public let authors: String
    public let institution: String
    public let year: Int
    public let copyright: String
    public let sources: [String]
    /// Card-by-card verification status against the source PDFs (chore C1).
    public let verification: String
}

/// A versioned deck: the instrument's provenance plus its cards.
///
/// Deliberately **not** `Codable`. The deck is compiled into the binary from
/// `data/deck.v1.json` (see `scripts/generate_deck.py`), so there is no JSON
/// resource in the shipped app to parse — and therefore none to swap. Adding a
/// decoder here would put that editing surface back.
public struct Deck: Hashable, Sendable {
    public let deckVersion: String
    public let instrument: Instrument
    /// Redundant with `cards.count` on purpose — see ``DeckLoader``.
    public let cardCount: Int
    public let cards: [ValueCard]

    /// Built once at construction. Export (R8) and the sort screen look cards
    /// up by id constantly; a linear scan per lookup would be quietly
    /// quadratic. Derived state, so it is excluded from `Hashable` and `==`.
    private let index: [Int: ValueCard]

    public init(
        deckVersion: String,
        instrument: Instrument,
        cardCount: Int,
        cards: [ValueCard]
    ) {
        self.deckVersion = deckVersion
        self.instrument = instrument
        self.cardCount = cardCount
        self.cards = cards
        // Non-trapping: a duplicate id must surface as a thrown
        // `DeckError.duplicateIDs` from `DeckLoader.validate`, not as a crash
        // here, before validation ever gets to run.
        self.index = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static func == (lhs: Deck, rhs: Deck) -> Bool {
        lhs.deckVersion == rhs.deckVersion
            && lhs.instrument == rhs.instrument
            && lhs.cardCount == rhs.cardCount
            && lhs.cards == rhs.cards
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(deckVersion)
        hasher.combine(cards)
    }

    /// The card with this printed number, or `nil` if the deck has no such card.
    public subscript(id: Int) -> ValueCard? { index[id] }
}
