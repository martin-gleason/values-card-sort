// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// R1 — "Deck order is a uniform random shuffle (Fisher–Yates) fixed at
/// session start and persisted." (SPEC §5.2)
@Suite("R1 — Shuffle")
struct R1_ShuffleTests {
    private func deck() throws -> Deck { try DeckLoader.load() }

    @Test("R1_shuffleIsCompletePermutation")
    func shuffleIsCompletePermutation() throws {
        let deck = try deck()
        let ids = deck.cards.map { CardID.deck($0.id) }

        // Many seeds, because a shuffle that loses a card only sometimes is
        // the exact bug this rule exists to prevent.
        for seed in UInt64(1)...50 {
            var generator = SeededGenerator(seed: seed)
            let shuffled = Shuffler.fisherYates(ids, using: &generator)

            #expect(shuffled.count == ids.count, "seed \(seed) changed the card count")
            #expect(Set(shuffled) == Set(ids), "seed \(seed) lost or invented a card")
            #expect(Set(shuffled).count == shuffled.count, "seed \(seed) duplicated a card")
        }
    }

    @Test("R1_shuffleIsDeterministicUnderSeed")
    func shuffleIsDeterministicUnderSeed() throws {
        let ids = try deck().cards.map { CardID.deck($0.id) }

        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        var c = SeededGenerator(seed: 43)

        let first = Shuffler.fisherYates(ids, using: &a)
        let same = Shuffler.fisherYates(ids, using: &b)
        let different = Shuffler.fisherYates(ids, using: &c)

        #expect(first == same, "the same seed must reproduce the same order")
        #expect(first != different, "different seeds must not collide")
    }

    @Test("R1_shuffleActuallyReorders")
    func shuffleActuallyReorders() throws {
        // A shuffle that returns its input passes "is a permutation" happily.
        let ids = try deck().cards.map { CardID.deck($0.id) }
        var generator = SeededGenerator(seed: 7)
        let shuffled = Shuffler.fisherYates(ids, using: &generator)
        #expect(shuffled != ids)

        let movedCount = zip(ids, shuffled).count { $0 != $1 }
        #expect(movedCount > ids.count / 2, "only \(movedCount) of \(ids.count) cards moved")
    }

    @Test("R1_shuffleIsUniform", .timeLimit(.minutes(1)))
    func shuffleIsUniform() {
        // Every element must reach every position. With a biased Fisher-Yates
        // (the classic `random(in: 0..<count)` mistake) some positions become
        // measurably unreachable or over-represented for small n.
        let items = Array(0..<6)
        var generator = SeededGenerator(seed: 2001)
        var seenPermutations: Set<[Int]> = []

        for _ in 0..<5_000 {
            seenPermutations.insert(Shuffler.fisherYates(items, using: &generator))
        }

        // 6! = 720. A correct uniform shuffle finds essentially all of them in
        // 5,000 draws; a biased one cannot reach some at all.
        #expect(seenPermutations.count == 720,
                "saw \(seenPermutations.count) of 720 permutations")
    }

    @Test("R1_edgeCases")
    func edgeCases() {
        var generator = SeededGenerator(seed: 1)
        #expect(Shuffler.fisherYates([Int](), using: &generator).isEmpty)
        #expect(Shuffler.fisherYates([9], using: &generator) == [9])
    }

    // MARK: - "fixed at session start and persisted"

    @Test("R1_shuffleOrderIsFixedAtSessionStart")
    func shuffleOrderIsFixedAtSessionStart() throws {
        var generator = SeededGenerator(seed: 99)
        var session = SessionState(deck: try deck(), using: &generator)
        let originalShuffle = session.shuffleOrder

        #expect(session.queue == originalShuffle, "the queue starts as the shuffle")

        // Consume the queue the way sorting does.
        for _ in 0..<20 {
            let card = session.queue.removeFirst()
            session[.important].append(card)
        }

        #expect(session.shuffleOrder == originalShuffle,
                "sorting must not mutate the recorded shuffle (SPEC §5.1 lists it as its own field)")
        #expect(session.queue.count == originalShuffle.count - 20)
        #expect(session.isWellFormed)
    }

    @Test("R1_sessionStartsWithEveryCardInTheQueue")
    func sessionStartsWithEveryCardInTheQueue() throws {
        let deck = try deck()
        var generator = SeededGenerator(seed: 5)
        let session = SessionState(deck: deck, using: &generator)

        #expect(session.queue.count == 83)
        #expect(session.totalCards == 83)
        #expect(session.sortedCount == 0)
        let allPilesEmpty = session.piles.allSatisfy { $0.isEmpty }
        #expect(allPilesEmpty)
        #expect(session.phase == .sort)
        #expect(session.completedAt == nil)
        #expect(session.deckVersion == deck.deckVersion)
        #expect(session.isWellFormed)
    }

    @Test("R1_customCardsFromPriorSessionsJoinTheShuffle")
    func customCardsJoinTheShuffle() throws {
        // SPEC §5.1: prior sessions' custom cards are offered at session start.
        let mine = CustomCard(name: "community", descriptor: "to belong to a place")!
        var generator = SeededGenerator(seed: 11)
        let session = SessionState(deck: try deck(), customCards: [mine], using: &generator)

        #expect(session.shuffleOrder.count == 84)
        #expect(session.shuffleOrder.contains(mine.cardID))
        #expect(session.totalCards == 84)
        #expect(session.isWellFormed)
    }
}
