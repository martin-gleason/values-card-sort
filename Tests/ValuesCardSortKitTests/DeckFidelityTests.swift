// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// TESTING.md layer 1, asserted against the resource the app actually loads.
///
/// `scripts/check-deck.sh` asserts the same facts about the file on disk. Both
/// exist because they catch different failures: the script catches a bad file,
/// these catch a good file that never made it into the bundle.
@Suite("Deck fidelity (SPEC §4)")
struct DeckFidelityTests {
    private func loadedDeck() throws -> Deck {
        try DeckLoader.load()
    }

    @Test("deck.v1.json is present in the bundle and parses")
    func deckLoads() throws {
        let deck = try loadedDeck()
        #expect(deck.deckVersion == "1.0.0")
    }

    @Test("cardCount == cards.count == 83")
    func cardCount() throws {
        let deck = try loadedDeck()
        #expect(deck.cardCount == 83)
        #expect(deck.cards.count == 83)
        #expect(deck.cardCount == deck.cards.count)
    }

    @Test("ids are contiguous 1…83 in file order")
    func idsAreContiguous() throws {
        let deck = try loadedDeck()
        #expect(deck.cards.map(\.id) == Array(1...83))
    }

    @Test("card names are unique")
    func namesAreUnique() throws {
        let deck = try loadedDeck()
        #expect(Set(deck.cards.map(\.name)).count == deck.cards.count)
    }

    @Test("card-payload SHA-256 matches the pinned hash")
    func payloadHashMatches() throws {
        let deck = try loadedDeck()
        let actual = DeckLoader.sha256(Deck.canonicalPayload(of: deck.cards))
        #expect(actual == Deck.payloadSHA256,
                "The 83 cards drifted. The deck is immutable (SPEC §4).")
    }

    /// The hash means nothing unless Swift and `scripts/check_deck.py` build
    /// the same bytes. This pins the serialization itself, so a well-meaning
    /// refactor of `canonicalPayload` fails here instead of silently
    /// decoupling the two gates.
    @Test("canonical payload serialization is separator-delimited as specified")
    func canonicalPayloadFormat() {
        let cards = [
            ValueCard(id: 1, name: "ACCEPTANCE", descriptor: "to be accepted as I am"),
            ValueCard(id: 2, name: "ACCURACY", descriptor: "to be accurate in my opinions and beliefs"),
        ]
        let expected = "1\u{001F}ACCEPTANCE\u{001F}to be accepted as I am"
            + "\u{001E}"
            + "2\u{001F}ACCURACY\u{001F}to be accurate in my opinions and beliefs"
        #expect(Deck.canonicalPayload(of: cards) == expected)
    }

    @Test("the deck is pure ASCII, so the separators cannot collide with data")
    func deckIsASCII() throws {
        let deck = try loadedDeck()
        for card in deck.cards {
            let nameIsASCII = card.name.allSatisfy { $0.isASCII }
            let descriptorIsASCII = card.descriptor.allSatisfy { $0.isASCII }
            #expect(nameIsASCII, "non-ASCII in \(card.name)")
            #expect(descriptorIsASCII, "non-ASCII in \(card.name)")
        }
    }

    @Test("attribution travels with the data (SPEC §2, §8)")
    func instrumentProvenance() throws {
        let deck = try loadedDeck()
        #expect(deck.instrument.year == 2001)
        #expect(deck.instrument.institution == "University of New Mexico")
        #expect(deck.instrument.copyright == "Public domain")
        #expect(deck.instrument.authors.contains("Miller"))
        #expect(!deck.instrument.sources.isEmpty)
    }

    @Test("known cards match the printed instrument exactly")
    func spotCheckCards() throws {
        let deck = try loadedDeck()
        #expect(deck[1] == ValueCard(id: 1, name: "ACCEPTANCE", descriptor: "to be accepted as I am"))
        #expect(deck[83] == ValueCard(id: 83, name: "WORLD PEACE", descriptor: "to work to promote peace in the world"))
        #expect(deck[33]?.name == "GOD'S WILL", "apostrophes must survive JSON decoding")
        #expect(deck[54]?.name == "NON-CONFORMITY", "hyphens must survive JSON decoding")
    }

    // MARK: - The validator must actually reject bad decks

    @Test("a deck whose cardCount disagrees with its cards is rejected")
    func rejectsCountMismatch() throws {
        let deck = try loadedDeck()
        let tampered = try mutate(deck) { $0["cardCount"] = 82 }
        #expect(throws: DeckError.countMismatch(declared: 82, actual: 83)) {
            try DeckLoader.decode(tampered)
        }
    }

    @Test("a deck with a drifted card is rejected")
    func rejectsCardDrift() throws {
        let deck = try loadedDeck()
        let tampered = try mutate(deck) { json in
            var cards = json["cards"] as! [[String: Any]]
            cards[4]["descriptor"] = "to be physically ATTRACTIVE"
            json["cards"] = cards
        }
        #expect(throws: DeckError.self) { try DeckLoader.decode(tampered) }
    }

    @Test("a deck with non-contiguous ids is rejected")
    func rejectsNonContiguousIDs() throws {
        let deck = try loadedDeck()
        let tampered = try mutate(deck) { json in
            var cards = json["cards"] as! [[String: Any]]
            cards[10]["id"] = 999
            json["cards"] = cards
        }
        #expect(throws: DeckError.self) { try DeckLoader.decode(tampered) }
    }

    /// Round-trips the real deck through JSON so a test can perturb one field
    /// without a second copy of the deck existing anywhere in the repo.
    private func mutate(_ deck: Deck, _ change: (inout [String: Any]) -> Void) throws -> Data {
        let data = try JSONEncoder().encode(deck)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        change(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }
}
