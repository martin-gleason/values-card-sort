// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// R2 — "One card at a time from the front of the queue; the sorter assigns it
/// to exactly one of five piles." (SPEC §5.2)
@Suite("R2 — Sort")
struct R2_AssignTests {
    private func session(seed: UInt64 = 202) throws -> SessionState {
        var generator = SeededGenerator(seed: seed)
        return SessionState(deck: try DeckLoader.load(), using: &generator)
    }

    @Test("R2_assignmentMovesTheFrontCardIntoExactlyOnePile")
    func assignmentMovesTheFrontCardIntoExactlyOnePile() throws {
        var session = try session()
        let card = try #require(session.currentCard)
        let nextCard = session.queue[1]

        session.assign(to: .veryImportant)

        #expect(session[.veryImportant] == [card])
        #expect(session.currentCard == nextCard, "the queue advances by exactly one")
        #expect(session.queue.count == 82)
        #expect(session.sortedCount == 1)

        // "exactly one of five piles" — the other four are untouched.
        let elsewhere = Pile.allCases.filter { $0 != .veryImportant }.flatMap { session[$0] }
        #expect(elsewhere.isEmpty, "the card landed in more than one pile")

        #expect(session.history == [SortMove(card: card, pile: .veryImportant)])
        #expect(session.isWellFormed)
    }

    @Test("R2_pileOrderIsAssignmentOrder")
    func pileOrderIsAssignmentOrder() throws {
        // Guards R6 downstream: kept order is surviving *Most important*
        // order, so appending (not inserting) here is what makes the ranked
        // export reflect the order the sorter actually built.
        var session = try session()
        var expected: [CardID] = []

        for _ in 0..<6 {
            let card = try #require(session.currentCard)
            expected.append(card)
            session.assign(to: .mostImportant)
            #expect(session.isWellFormed)
        }

        #expect(session[.mostImportant] == expected,
                "the pile must read in assignment order, oldest first")
        #expect(session.history.map(\.card) == expected)
    }

    @Test("R2_assignOnEmptyQueueIsANoOp")
    func assignOnEmptyQueueIsANoOp() throws {
        var session = try session()
        while session.currentCard != nil {
            session.assign(to: .important)
        }
        let drained = session

        session.assign(to: .notImportant)

        #expect(session == drained, "assigning with an empty queue must change nothing")
        #expect(session[.notImportant].isEmpty)
        #expect(session.history.count == 83)
        #expect(session.isWellFormed)
    }

    @Test("R2_everyPileTakesCardsAndTheTotalIsConserved")
    func everyPileTakesCardsAndTheTotalIsConserved() throws {
        var session = try session(seed: 77)
        var placed = 0

        while let _ = session.currentCard {
            session.assign(to: Pile.allCases[placed % Pile.allCases.count])
            placed += 1
            #expect(session.isWellFormed)
        }

        #expect(session.queue.isEmpty)
        #expect(session.piles.map(\.count).reduce(0, +) == 83)
        #expect(session.piles.allSatisfy { !$0.isEmpty })
        #expect(session.sortedCount == session.totalCards)
    }
}
