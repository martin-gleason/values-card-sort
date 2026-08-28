// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// R10 — "The app resumes an in-progress session exactly where it left off,
/// mid-phase, across launches." (SPEC §5.2)
///
/// At this layer that is a `Codable` round-trip property: if the state encodes
/// and decodes identically, resume is correct by construction, and the app's
/// SwiftData test covers the storage half.
@Suite("R10 — Resume")
struct R10_PersistenceTests {
    /// A session stopped in the middle of cull with something in every field
    /// R10 has to preserve — the state most likely to lose information.
    private func midCullFixture() throws -> SessionState {
        let deck = try DeckLoader.load()
        let mine = CustomCard(name: "wisdom", descriptor: "to know what matters")!
        var generator = SeededGenerator(seed: 2026)
        var session = SessionState(deck: deck, customCards: [mine], using: &generator)

        // Sort every card, round-robin across the piles.
        var pileIndex = 0
        while let card = session.queue.first {
            let pile = Pile.allCases[pileIndex % Pile.allCases.count]
            session.queue.removeFirst()
            session[pile].append(card)
            session.history.append(SortMove(card: card, pile: pile))
            pileIndex += 1
        }

        session.phase = .cull
        session.cut = Array(session[.mostImportant].prefix(3))
        session.promotions = Array(session[.veryImportant].prefix(2))
        session.themeID = "civic"
        return session
    }

    @Test("R10_midPhaseStateRoundTripsThroughCodable")
    func midPhaseStateRoundTrips() throws {
        let original = try midCullFixture()

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(SessionState.self, from: data)

        #expect(restored == original, "the session did not survive a round trip")
    }

    /// `==` would pass even if a field were dropped from *both* sides by a bad
    /// refactor of `Codable`, so the fields R10 depends on are named.
    @Test("R10_everyFieldSurvivesTheRoundTrip")
    func everyFieldSurvives() throws {
        let original = try midCullFixture()
        let restored = try JSONDecoder().decode(
            SessionState.self, from: try JSONEncoder().encode(original)
        )

        #expect(restored.id == original.id)
        #expect(restored.startedAt.timeIntervalSince1970 == original.startedAt.timeIntervalSince1970)
        #expect(restored.completedAt == original.completedAt)
        #expect(restored.deckVersion == original.deckVersion)
        #expect(restored.shuffleOrder == original.shuffleOrder)
        #expect(restored.queue == original.queue)
        #expect(restored.piles == original.piles)
        #expect(restored.history == original.history)
        #expect(restored.cut == original.cut)
        #expect(restored.ranking == original.ranking)
        #expect(restored.customCards == original.customCards)
        #expect(restored.phase == original.phase)
        #expect(restored.themeID == original.themeID)
        #expect(restored.isWellFormed)
    }

    /// R6 defines kept order as survivors *then promotions in promotion order*.
    /// If promotions ever became a `Set`, or serialized as one, R6 would break
    /// in a way that only shows up as a subtly wrong ranking screen.
    @Test("R10_promotionOrderSurvivesPersistence")
    func promotionOrderSurvives() throws {
        var session = try midCullFixture()
        session.promotions = Array(session[.veryImportant].prefix(4)).reversed()
        let expected = session.promotions

        let restored = try JSONDecoder().decode(
            SessionState.self, from: try JSONEncoder().encode(session)
        )

        #expect(restored.promotions == expected, "promotion ORDER is load-bearing for R6")
    }

    @Test("R10_customCardIdentityIsStableAcrossLaunches")
    func customCardIdentityIsStable() throws {
        // The reference implementation keys custom cards on `"c" + Date.now()`.
        // If the native port regenerated ids on load, a resumed session would
        // lose every custom card that had already been sorted into a pile.
        let session = try midCullFixture()
        let restored = try JSONDecoder().decode(
            SessionState.self, from: try JSONEncoder().encode(session)
        )

        let custom = try #require(restored.customCards.first)
        #expect(custom.id == session.customCards[0].id)
        #expect(restored.shuffleOrder.contains(custom.cardID))
        #expect(restored.isWellFormed)
    }

    @Test("R10_cardIDEncodesAsAReadableString")
    func cardIDEncoding() throws {
        let uuid = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00CF4FC964FF")!
        let ids: [CardID] = [.deck(42), .custom(uuid)]

        let data = try JSONEncoder().encode(ids)
        #expect(String(decoding: data, as: UTF8.self) == #"["deck:42","custom:6F9619FF-8B86-D011-B42D-00CF4FC964FF"]"#)
        #expect(try JSONDecoder().decode([CardID].self, from: data) == ids)
    }

    @Test("R10_aCorruptCardIDIsRejectedRatherThanGuessed")
    func corruptCardIDRejected() {
        let data = Data(#"["banana:1"]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([CardID].self, from: data)
        }
    }
}

/// R4's construction rules, which the session model depends on.
@Suite("R4 — Custom card construction")
struct R4_CustomCardTests {
    @Test("name is required and uppercased")
    func nameRequiredAndUppercased() {
        #expect(CustomCard(name: "community")?.name == "COMMUNITY")
        #expect(CustomCard(name: "  quiet mornings  ")?.name == "QUIET MORNINGS")
        #expect(CustomCard(name: "") == nil)
        #expect(CustomCard(name: "   ") == nil)
    }

    @Test("descriptor defaults when omitted or blank")
    func descriptorDefaults() {
        #expect(CustomCard(name: "X")?.descriptor == CustomCard.defaultDescriptor)
        #expect(CustomCard(name: "X", descriptor: "  ")?.descriptor == CustomCard.defaultDescriptor)
        #expect(CustomCard(name: "X", descriptor: "to rest")?.descriptor == "to rest")
    }
}
