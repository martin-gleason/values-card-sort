// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

@testable import ValuesCardSortKit

/// Independent verification of F2-T1. Not part of the deliverable — these exist
/// to try to break R2/R3/R4 and the ``SessionState/isWellFormed`` validator.
@Suite("ZZ — Adversarial verification of F2-T1")
struct ZZ_AdversarialVerificationTests {
    private func session(seed: UInt64) throws -> SessionState {
        var generator = SeededGenerator(seed: seed)
        return SessionState(deck: try DeckLoader.load(), using: &generator)
    }

    // MARK: - A. Brute-force model, JSX semantics, random interleaving

    /// A deliberately dumb reimplementation of the reference's `assign`,
    /// `undo`, `addCustom` (valuescardsort.jsx:172-194), including its
    /// `filter`-based pile removal. Any divergence from `SessionState` on a
    /// well-formed run is a port bug.
    private struct Model {
        var queue: [CardID]
        var piles: [[CardID]] = Array(repeating: [], count: 5)
        var history: [(id: CardID, p: Int)] = []
        var custom: [CardID] = []

        mutating func assign(_ p: Int) {
            guard !queue.isEmpty else { return }
            let id = queue[0]
            piles[p].append(id)
            history.append((id, p))
            queue.removeFirst()
        }

        mutating func undo() {
            guard let last = history.last else { return }
            piles[last.p] = piles[last.p].filter { $0 != last.id }
            queue.insert(last.id, at: 0)
            history.removeLast()
        }

        mutating func addCustom(_ id: CardID) {
            custom.append(id)
            queue.insert(id, at: 0)
        }
    }

    @Test("ZZ_interleavedAssignUndoAddMatchesABruteForceModelOfTheReference")
    func interleavedMatchesModel() throws {
        for seed in UInt64(1)...12 {
            var session = try session(seed: seed)
            var model = Model(queue: session.queue)
            var rng = SeededGenerator(seed: seed &* 7919 &+ 13)
            var customCounter = 0

            for step in 0..<400 {
                switch Int.random(in: 0..<10, using: &rng) {
                case 0...5:
                    let pile = Pile.allCases[Int.random(in: 0..<5, using: &rng)]
                    session.assign(to: pile)
                    model.assign(pile.rawValue)
                case 6...8:
                    session.undo()
                    model.undo()
                default:
                    customCounter += 1
                    let made = session.addCustomCard(name: "written \(customCounter)")
                    let card = try #require(made)
                    model.addCustom(card.cardID)
                }

                #expect(session.queue == model.queue, "seed \(seed) step \(step): queue diverged")
                #expect(session.piles == model.piles, "seed \(seed) step \(step): piles diverged")
                #expect(session.history.map(\.card) == model.history.map(\.id))
                #expect(session.history.map(\.pile.rawValue) == model.history.map(\.p))
                #expect(session.customCards.map(\.cardID) == model.custom)
                #expect(session.isWellFormed, "seed \(seed) step \(step): invariant broken")
                #expect(
                    session.sortedCount == session.totalCards - session.queue.count,
                    "seed \(seed) step \(step): counters diverged"
                )
            }
        }
    }

    // MARK: - B. Undo of a custom-card placement

    @Test("ZZ_undoingACustomCardPlacementReturnsItToTheQueueNotTheVoid")
    func undoingACustomCardPlacement() throws {
        var session = try session(seed: 991)
        let written = try #require(session.addCustomCard(name: "belonging"))
        #expect(session.currentCard == written.cardID)

        session.assign(to: .mostImportant)
        #expect(session[.mostImportant] == [written.cardID])
        #expect(session.customCards == [written])

        session.undo()

        #expect(session.currentCard == written.cardID, "the written card must come back")
        #expect(session[.mostImportant].isEmpty)
        #expect(session.customCards == [written], "undo must not delete the card's text")
        #expect(session.totalCards == 84)
        #expect(session.isWellFormed)
    }

    // MARK: - C. Drain, add, assign, then unwind the whole thing

    @Test("ZZ_drainThenAddThenAssignThenFullyUnwindToTheOriginalSession")
    func drainAddAssignUnwind() throws {
        var session = try session(seed: 992)
        let fresh = session

        while session.currentCard != nil { session.assign(to: .veryImportant) }
        let written = try #require(session.addCustomCard(name: "afterthought"))
        session.assign(to: .notImportant)
        #expect(session.queue.isEmpty)
        #expect(session.sortedCount == 84)
        #expect(session.isWellFormed)

        while !session.history.isEmpty {
            session.undo()
            #expect(session.isWellFormed)
        }

        // Everything unwinds, but the written card is still in the deck: it was
        // never a placement, so history cannot remove it.
        #expect(session.piles.allSatisfy(\.isEmpty))
        #expect(session.queue.count == 84)
        #expect(session.customCards == [written])
        #expect(session.queue.last == fresh.shuffleOrder.last)
        #expect(session.queue.contains(written.cardID))
        #expect(Set(session.queue) == Set(fresh.queue).union([written.cardID]))
        #expect(session.isWellFormed)
    }

    @Test("ZZ_mutationsSurviveACodableRoundTripUnchanged")
    func mutationsRoundTrip() throws {
        var session = try session(seed: 993)
        for pile in Pile.allCases { session.assign(to: pile) }
        _ = session.addCustomCard(name: "quiet", descriptor: "room to think")
        session.assign(to: .important)
        session.undo()

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(SessionState.self, from: data)
        #expect(restored == session)
        #expect(restored.isWellFormed)
    }

    // MARK: - D. Does isWellFormed actually fail?

    @Test("ZZ_isWellFormedRejectsEveryCorruptionItClaimsToCatch")
    func isWellFormedRejectsCorruption() throws {
        let base = try session(seed: 994)
        #expect(base.isWellFormed, "the control must be well formed")

        // 1. Wrong number of piles.
        var wrongPileCount = base
        wrongPileCount.piles.removeLast()
        #expect(!wrongPileCount.isWellFormed)

        // 2. A duplicated card — in the queue and in a pile at once. This is
        //    the exact failure a half-applied undo produces.
        var duplicated = base
        duplicated[.important] = [try #require(duplicated.currentCard)]
        #expect(!duplicated.isWellFormed)

        // 3. A lost card — dropped from the queue and placed nowhere.
        var lost = base
        lost.queue.removeFirst()
        #expect(!lost.isWellFormed)

        // 4. A card that was never dealt.
        var foreign = base
        foreign.queue.append(.custom(UUID()))
        #expect(!foreign.isWellFormed)

        // 5. A custom card whose text exists but whose card is nowhere.
        var orphanText = base
        orphanText.customCards.append(try #require(CustomCard(name: "ghost")))
        #expect(!orphanText.isWellFormed)

        // 6. Cut cards must live in Most important.
        var badCut = base
        badCut.cut = [try #require(badCut.queue.first)]
        #expect(!badCut.isWellFormed)

        // 7. Promotions must come out of Very important.
        var badPromotion = base
        badPromotion.assign(to: .mostImportant)
        badPromotion.promotions = [try #require(badPromotion[.mostImportant].first)]
        #expect(!badPromotion.isWellFormed)

        // 8. A card cannot be both cut and promoted.
        var cutAndPromoted = base
        cutAndPromoted.assign(to: .mostImportant)
        cutAndPromoted.assign(to: .veryImportant)
        let mostCard = try #require(cutAndPromoted[.mostImportant].first)
        cutAndPromoted.cut = [mostCard]
        cutAndPromoted.promotions = [mostCard]
        #expect(!cutAndPromoted.isWellFormed)

        // 9. Duplicates inside the ordered cull lists.
        var duplicateCut = base
        duplicateCut.assign(to: .mostImportant)
        let cutCard = try #require(duplicateCut[.mostImportant].first)
        duplicateCut.cut = [cutCard, cutCard]
        #expect(!duplicateCut.isWellFormed)

        // 10. Ranking holding a card that is not in the session at all.
        var badRanking = base
        badRanking.ranking = [.deck(9999)]
        #expect(!badRanking.isWellFormed)

        // 11. Ranking holding the same card twice.
        var duplicateRanking = base
        let rankCard = try #require(duplicateRanking.queue.first)
        duplicateRanking.ranking = [rankCard, rankCard]
        #expect(!duplicateRanking.isWellFormed)
    }

    // MARK: - E. Counter honesty under a custom card that was present at start

    @Test("ZZ_countersStayHonestWhenTheSessionStartedWithCustomCards")
    func countersWithPreexistingCustomCards() throws {
        var generator = SeededGenerator(seed: 995)
        let carried = try #require(CustomCard(name: "carried over"))
        var session = SessionState(
            deck: try DeckLoader.load(),
            customCards: [carried],
            using: &generator
        )
        #expect(session.totalCards == 84, "a carried-in card is dealt, not added")
        #expect(session.isWellFormed)

        let added = try #require(session.addCustomCard(name: "written now"))
        #expect(session.totalCards == 85)
        #expect(session.sortedCount == 0)
        #expect(session.currentCard == added.cardID)
        #expect(session.isWellFormed)

        while session.currentCard != nil { session.assign(to: .notImportant) }
        #expect(session.sortedCount == 85)
        #expect(session[.notImportant].count == 85)
        #expect(session.isWellFormed)
    }
}
