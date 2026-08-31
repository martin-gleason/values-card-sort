// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// R3 — "Undo is LIFO over the sort history; the undone card returns to the
/// **front** of the queue and leaves its pile." (SPEC §5.2)
@Suite("R3 — Undo")
struct R3_UndoTests {
    private func session(seed: UInt64 = 303) throws -> SessionState {
        var generator = SeededGenerator(seed: seed)
        return SessionState(deck: try DeckLoader.load(), using: &generator)
    }

    @Test("R3_undoIsLIFOAndReturnsTheCardToTheFront")
    func undoIsLIFOAndReturnsTheCardToTheFront() throws {
        var session = try session()
        let first = try #require(session.currentCard)
        session.assign(to: .notImportant)
        let second = try #require(session.currentCard)
        session.assign(to: .mostImportant)

        session.undo()

        #expect(session.currentCard == second, "the most recent placement comes back first")
        #expect(session[.mostImportant].isEmpty, "the undone card must leave its pile")
        #expect(session[.notImportant] == [first], "an earlier placement is untouched")
        #expect(session.history == [SortMove(card: first, pile: .notImportant)])
        #expect(session.sortedCount == 1)
        #expect(session.isWellFormed)
    }

    @Test("R3_undoOnEmptyHistoryIsANoOp")
    func undoOnEmptyHistoryIsANoOp() throws {
        var session = try session()
        let fresh = session

        session.undo()
        #expect(session == fresh, "undo with nothing to undo must change nothing")

        // And after unwinding everything, one undo too many is still a no-op.
        session.assign(to: .important)
        session.undo()
        session.undo()
        #expect(session == fresh)
        #expect(session.isWellFormed)
    }

    @Test("R3_undoAfterManyAssignmentsUnwindsInReverseOrder")
    func undoAfterManyAssignmentsUnwindsInReverseOrder() throws {
        var session = try session(seed: 31)
        let fresh = session
        let assignments: [Pile] = [
            .important, .notImportant, .mostImportant, .veryImportant,
            .somewhatImportant, .mostImportant, .important,
        ]
        var order: [CardID] = []

        for pile in assignments {
            order.append(try #require(session.currentCard))
            session.assign(to: pile)
        }

        for expected in order.reversed() {
            session.undo()
            #expect(session.currentCard == expected,
                    "undo must unwind in reverse assignment order")
            #expect(session.isWellFormed)
        }

        // Fully unwound, the session is byte-for-byte what it was: the queue is
        // back in shuffle order, every pile is empty, history is empty.
        #expect(session == fresh)
        #expect(session.queue == session.shuffleOrder)
    }

    @Test("R3_undoReturnsACardToTheFrontEvenWhenTheQueueIsEmpty")
    func undoReturnsACardToTheFrontEvenWhenTheQueueIsEmpty() throws {
        // The realistic case for undo is the sorter changing their mind about
        // the last card of the deck, from the queue-empty interstitial.
        var session = try session(seed: 32)
        while session.currentCard != nil {
            session.assign(to: .somewhatImportant)
        }
        let last = try #require(session.history.last?.card)

        session.undo()

        #expect(session.queue == [last])
        #expect(session.currentCard == last)
        #expect(!session[.somewhatImportant].contains(last))
        #expect(session.isWellFormed)
    }

    @Test("R3_undoDoesNotDisturbACustomCardAddedAfterwards")
    func undoDoesNotDisturbACustomCardAddedAfterwards() throws {
        // History records placements only, so undo pushes the placed card in
        // front of a custom card written since. Documented in the F2 plan as an
        // assumption; pinned here so a future change to it is deliberate.
        var session = try session(seed: 33)
        let placed = try #require(session.currentCard)
        session.assign(to: .important)
        let addedWritten = session.addCustomCard(name: "stillness")
        let written = try #require(addedWritten)

        session.undo()

        #expect(session.queue.first == placed)
        #expect(session.queue.dropFirst().first == written.cardID)
        #expect(session.customCards == [written], "undo must not delete a custom card")
        #expect(session.isWellFormed)
    }
}
