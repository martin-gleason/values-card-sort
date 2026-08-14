// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// One card placement, kept so undo can be exact (R3).
public struct SortMove: Codable, Hashable, Sendable {
    public let card: CardID
    public let pile: Pile

    public init(card: CardID, pile: Pile) {
        self.card = card
        self.pile = pile
    }
}

/// A complete run of the instrument (SPEC §5.1).
///
/// A value type, `Codable` end to end, holding every field SPEC §5.1 names.
/// The app persists it as an opaque blob inside a SwiftData record rather than
/// modelling each field as a stored property — that keeps the rules layer free
/// of SwiftData (so `swift test` needs no simulator) and keeps the persistence
/// schema from having to change every time a rule does.
///
/// R10 (resume mid-phase across launches) is therefore a `Codable` round-trip
/// property, and is tested as one.
public struct SessionState: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    /// `nil` while in progress. At most one session may be in progress
    /// (SPEC §5.1); the app's store enforces that, not this type.
    public var completedAt: Date?
    /// Which deck version this session was sorted against, so an archived
    /// session stays interpretable after a future `deck.v2.json`.
    public let deckVersion: String

    /// The shuffle fixed at session start (R1), persisted and **never mutated**.
    ///
    /// Stored separately from ``queue`` on purpose. The reference
    /// implementation keeps only the shrinking queue, which means the original
    /// draw order is destroyed as you sort; SPEC §5.1 lists "shuffle order" as
    /// a session field in its own right.
    public let shuffleOrder: [CardID]

    /// Cards not yet sorted, front first. Custom cards are inserted at the
    /// front (R4); undone cards return to the front (R3).
    public var queue: [CardID]

    /// Pile contents, indexed by `Pile.rawValue`. Always exactly five entries —
    /// see ``isWellFormed``.
    public var piles: [[CardID]]

    /// Placements in order, for LIFO undo (R3).
    public var history: [SortMove]

    /// Cards cut from *Most important* during cull (R5). Ordered rather than a
    /// `Set` so the UI can show cuts in the order they were made.
    public var cut: [CardID]

    /// Cards promoted out of *Very important* during cull (R5).
    ///
    /// **Order is load-bearing**: R6 defines kept order as surviving
    /// *Most important* order followed by promotions *in promotion order*. A
    /// `Set` here would satisfy the type checker and quietly break R6.
    public var promotions: [CardID]

    /// The kept values in the sorter's chosen order; position 1 is most
    /// central (R7). Empty until cull completes.
    public var ranking: [CardID]

    /// Cards the sorter wrote (R4), carrying their own text.
    public var customCards: [CustomCard]

    public var phase: SessionPhase

    /// The theme in use, recorded on the session (SPEC §5.3). `"note-card"` is
    /// the default until F8 ships the theme engine.
    public var themeID: String

    public static let defaultThemeID = "note-card"

    // MARK: - Creation

    /// Starts a session: shuffles the deck (R1) and puts the whole shuffle in
    /// the queue.
    public init(
        deck: Deck,
        customCards: [CustomCard] = [],
        id: UUID = UUID(),
        startedAt: Date = Date(),
        themeID: String = Self.defaultThemeID,
        using generator: inout some RandomNumberGenerator
    ) {
        let ids = deck.cards.map { CardID.deck($0.id) } + customCards.map(\.cardID)
        let shuffled = Shuffler.fisherYates(ids, using: &generator)

        self.id = id
        self.startedAt = startedAt
        self.completedAt = nil
        self.deckVersion = deck.deckVersion
        self.shuffleOrder = shuffled
        self.queue = shuffled
        self.piles = Array(repeating: [], count: Pile.allCases.count)
        self.history = []
        self.cut = []
        self.promotions = []
        self.ranking = []
        self.customCards = customCards
        self.phase = .sort
        self.themeID = themeID
    }

    /// Starts a session using the system random number generator.
    public init(deck: Deck, customCards: [CustomCard] = [], themeID: String = Self.defaultThemeID) {
        var generator = SystemRandomNumberGenerator()
        self.init(deck: deck, customCards: customCards, themeID: themeID, using: &generator)
    }

    // MARK: - Access

    public subscript(pile: Pile) -> [CardID] {
        get { piles[pile.rawValue] }
        set { piles[pile.rawValue] = newValue }
    }

    public func count(in pile: Pile) -> Int { self[pile].count }

    /// The card at the front of the queue — the one being sorted (R2).
    public var currentCard: CardID? { queue.first }

    /// Total cards in this session: the deck plus anything written (R4).
    public var totalCards: Int { shuffleOrder.count + cardsAddedAfterStart }

    private var cardsAddedAfterStart: Int {
        customCards.filter { !shuffleOrder.contains($0.cardID) }.count
    }

    public var sortedCount: Int { totalCards - queue.count }

    public var isComplete: Bool { completedAt != nil }

    // MARK: - Invariants

    /// Every card is in exactly one place: the queue or one pile, never both,
    /// never neither.
    ///
    /// This is the invariant R3 and R4 are most likely to break — the
    /// reference implementation's undo removes from a pile and prepends to the
    /// queue in two separate state updates, and a native port that forgets one
    /// half duplicates or loses a card silently. Tests assert this after every
    /// mutation; the app asserts it in debug builds.
    public var isWellFormed: Bool {
        guard piles.count == Pile.allCases.count else { return false }

        let placed = queue + piles.flatMap { $0 }
        guard Set(placed).count == placed.count else { return false }

        var expected = Set(shuffleOrder)
        expected.formUnion(customCards.map(\.cardID))
        return Set(placed) == expected
    }
}
