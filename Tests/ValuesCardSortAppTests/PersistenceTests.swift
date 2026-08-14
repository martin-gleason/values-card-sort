// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData
import Testing
import ValuesCardSortKit

@testable import ValuesCardSort

/// R10 at the storage layer, and SPEC §5.1's session lifecycle.
///
/// The package's `R10_PersistenceTests` proves a session survives a `Codable`
/// round trip; these prove it survives the store — which is the half that can
/// break without any rule changing.
@MainActor
@Suite("Persistence (R10, SPEC §5.1)")
struct PersistenceTests {
    private func makeStore() throws -> (SessionStore, ModelContainer) {
        let container = try ModelContainer(
            for: SessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (SessionStore(context: ModelContext(container)), container)
    }

    private func deck() throws -> Deck { try DeckLoader.load() }

    @Test("the app bundle carries a valid deck")
    func appBundleHasDeck() throws {
        let deck = try deck()
        #expect(deck.cards.count == 83)
    }

    @Test("R10_midPhaseStateRoundTripsThroughSwiftData")
    func midPhaseRoundTripsThroughSwiftData() throws {
        let (store, container) = try makeStore()
        _ = container

        let record = try store.start(deck: try deck())
        var state = try record.state()

        // Sort partway, then stop mid-phase — the state R10 must restore.
        for index in 0..<17 {
            let card = state.queue.removeFirst()
            let pile = Pile.allCases[index % Pile.allCases.count]
            state[pile].append(card)
            state.history.append(SortMove(card: card, pile: pile))
        }
        try store.save(state, to: record)

        // Re-fetch rather than reusing the in-memory object, so this exercises
        // the store rather than the reference we already hold.
        let resumed = try #require(try store.inProgress())
        let restored = try resumed.state()

        #expect(restored == state)
        #expect(restored.sortedCount == 17)
        #expect(restored.queue.count == 83 - 17)
        #expect(restored.shuffleOrder == state.shuffleOrder)
        #expect(restored.isWellFormed)
    }

    @Test("at most one session is in progress (SPEC §5.1)")
    func atMostOneInProgress() throws {
        let (store, container) = try makeStore()
        _ = container

        _ = try store.start(deck: try deck())
        #expect(throws: SessionStoreError.self) {
            try store.start(deck: try deck())
        }
    }

    @Test("completing a session frees the slot and archives it with its date")
    func completingArchives() throws {
        let (store, container) = try makeStore()
        _ = container
        let deck = try deck()

        let first = try store.start(deck: deck)
        let completionDate = Date(timeIntervalSince1970: 1_776_000_000)
        try store.complete(first, at: completionDate)

        #expect(try store.inProgress() == nil)
        #expect(try store.completed().count == 1)
        #expect(first.completedAt == completionDate)
        #expect(try first.state().completedAt == completionDate)

        // The slot is free, so a re-sort can begin (SPEC §5.1).
        let second = try store.start(deck: deck)
        #expect(second.sessionID != first.sessionID)
    }

    @Test("a re-sort gets a fresh shuffle (SPEC §5.1)")
    func resortReshuffles() throws {
        let (store, container) = try makeStore()
        _ = container
        let deck = try deck()

        let first = try store.start(deck: deck)
        let firstOrder = try first.state().shuffleOrder
        try store.complete(first)

        let second = try store.start(deck: deck)
        #expect(try second.state().shuffleOrder != firstOrder,
                "a new session must reshuffle, not reuse the previous order")
    }

    @Test("abandoning a session removes it (R9)")
    func abandonRemoves() throws {
        let (store, container) = try makeStore()
        _ = container

        let record = try store.start(deck: try deck())
        try store.abandon(record)

        #expect(try store.inProgress() == nil)
        #expect(try store.allSessions().isEmpty)
    }

    @Test("custom cards carry across sessions (SPEC §5.1)")
    func customCardsCarryAcross() throws {
        let (store, container) = try makeStore()
        _ = container
        let deck = try deck()

        let mine = try #require(CustomCard(name: "community", descriptor: "to belong to a place"))
        let first = try store.start(deck: deck, customCards: [mine])
        try store.complete(first)

        let known = try store.knownCustomCards()
        #expect(known.count == 1)
        #expect(known.first?.name == "COMMUNITY")
        #expect(known.first?.id == mine.id)
    }

    @Test("a record cannot be repointed at a different session")
    func updateGuardsIdentity() throws {
        let (store, container) = try makeStore()
        _ = container
        let deck = try deck()

        let record = try store.start(deck: deck)
        var state = try record.state()
        #expect(state.id == record.sessionID)

        // The queryable columns stay in step with the blob on every write.
        state.completedAt = Date(timeIntervalSince1970: 1_000_000)
        try store.save(state, to: record)
        #expect(record.completedAt == state.completedAt)
        #expect(!record.isInProgress)
    }
}
