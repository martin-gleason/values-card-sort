// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// R4 — "A user-written card (name required, uppercased; descriptor optional,
/// default 'a value I wrote myself') is inserted at the **front** of the queue.
/// Custom cards are available during Sort, including after the queue empties."
/// (SPEC §5.2)
@Suite("R4 — Custom card in the queue")
struct R4_CustomCardQueueTests {
    private func session(seed: UInt64 = 404) throws -> SessionState {
        var generator = SeededGenerator(seed: seed)
        return SessionState(deck: try DeckLoader.load(), using: &generator)
    }

    @Test("R4_customCardGoesToTheFrontOfTheQueue")
    func customCardGoesToTheFrontOfTheQueue() throws {
        var session = try session()
        let displaced = try #require(session.currentCard)

        let addedWritten = session.addCustomCard(name: "stillness", descriptor: "to be quiet")
        let written = try #require(addedWritten)

        #expect(session.currentCard == written.cardID, "the written card is sorted next")
        #expect(session.queue.dropFirst().first == displaced, "it displaces, it does not replace")
        #expect(session.queue.count == 84)
        #expect(session.customCards == [written])
        #expect(session.totalCards == 84, "a card added after the start counts toward the total")
        #expect(session.sortedCount == 0)
        #expect(session.isWellFormed)
    }

    @Test("R4_customCardNameIsUppercasedAndDescriptorDefaults")
    func customCardNameIsUppercasedAndDescriptorDefaults() throws {
        var session = try session()

        let addedWritten = session.addCustomCard(name: "  quiet courage  ")
        let written = try #require(addedWritten)
        #expect(written.name == "QUIET COURAGE", "trimmed and uppercased to sit with the printed cards")
        #expect(written.descriptor == "a value I wrote myself")

        // A descriptor of nothing but whitespace is a missing descriptor.
        let addedBlankDescriptor = session.addCustomCard(name: "candour", descriptor: "   ")
        let blankDescriptor = try #require(addedBlankDescriptor)
        #expect(blankDescriptor.descriptor == "a value I wrote myself")

        let addedGlossed = session.addCustomCard(name: "repair", descriptor: "  to mend what I broke  ")
        let glossed = try #require(addedGlossed)
        #expect(glossed.descriptor == "to mend what I broke")
        #expect(session.isWellFormed)
    }

    @Test("R4_customCardCanBeAddedAfterTheQueueEmpties")
    func customCardCanBeAddedAfterTheQueueEmpties() throws {
        // The queue-empty interstitial is a state *inside* Sort precisely so
        // this clause of R4 is implementable.
        var session = try session(seed: 41)
        while session.currentCard != nil {
            session.assign(to: .important)
        }
        #expect(session.queue.isEmpty)

        let addedWritten = session.addCustomCard(name: "late arrival")
        let written = try #require(addedWritten)

        #expect(session.queue == [written.cardID])
        #expect(session.currentCard == written.cardID)
        #expect(session.totalCards == 84)
        #expect(session.sortedCount == 83)
        #expect(session.isWellFormed)

        session.assign(to: .mostImportant)
        #expect(session[.mostImportant] == [written.cardID])
        #expect(session.queue.isEmpty)
        #expect(session.sortedCount == 84)
        #expect(session.isWellFormed)
    }

    @Test("R4_blankCustomCardNameIsRejected")
    func blankCustomCardNameIsRejected() throws {
        var session = try session()
        let fresh = session

        #expect(session.addCustomCard(name: "") == nil)
        #expect(session.addCustomCard(name: "   \n\t ") == nil)
        #expect(session.addCustomCard(name: " ", descriptor: "a real descriptor") == nil)

        #expect(session == fresh, "a rejected card must not touch the queue or the card list")
        #expect(session.customCards.isEmpty)
        #expect(session.isWellFormed)
    }

    @Test("R4_severalCustomCardsStackNewestFirst")
    func severalCustomCardsStackNewestFirst() throws {
        var session = try session(seed: 42)

        let addedFirst = session.addCustomCard(name: "one")
        let first = try #require(addedFirst)
        let addedSecond = session.addCustomCard(name: "two")
        let second = try #require(addedSecond)

        #expect(Array(session.queue.prefix(2)) == [second.cardID, first.cardID],
                "each new card goes in front of the last")
        #expect(session.customCards.map(\.name) == ["ONE", "TWO"],
                "the card list keeps creation order")
        #expect(session.isWellFormed)
    }
}
