// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The sort-phase verbs (R2, R3, R4).
///
/// F1 built ``SessionState`` as a container with no mutating operations; these
/// are the operations. They live in the rules layer, not the app, so
/// `swift test` can exercise R2–R4 without a simulator.
///
/// All three follow the reference implementation's guard-clause shape
/// (`reference/valuescardsort.jsx:172–200`): an operation with nothing to do is
/// a **no-op, not a trap**. The sort screen's buttons are allowed to be live at
/// the edges of the queue without the model punishing them for it.
extension SessionState {
    // MARK: - R2 — Sort

    /// Assigns the front card of the queue to `pile` (R2).
    ///
    /// **Appending rather than inserting is load-bearing.** R6 defines kept
    /// order as surviving *Most important* order, so a pile's order *is* its
    /// assignment order, and it survives all the way into the ranked export
    /// (R8). Inserting at the front here would type-check and silently reorder
    /// the finished document.
    ///
    /// A no-op when the queue is empty — the sorter can reach the queue-empty
    /// interstitial with the pile buttons still on screen (R4 keeps them
    /// company there).
    public mutating func assign(to pile: Pile) {
        guard !queue.isEmpty else { return }

        let card = queue.removeFirst()
        self[pile].append(card)
        history.append(SortMove(card: card, pile: pile))
    }

    // MARK: - R3 — Undo

    /// Undoes the most recent assignment (R3).
    ///
    /// LIFO over ``history``: the card leaves its pile and returns to the
    /// **front** of the queue, so it is the next card sorted. A no-op on empty
    /// history.
    ///
    /// History records placements only, so this does not undo a custom card
    /// (R4) — the reference implementation records the same thing, and SPEC R3
    /// scopes undo to "the sort history".
    public mutating func undo() {
        guard let move = history.last else { return }

        guard let index = self[move.pile].firstIndex(of: move.card) else {
            // History says the card is in this pile and it is not, so the
            // state was already malformed before we got here. Prepending it to
            // the queue anyway would turn a lost card into a duplicated one —
            // the exact failure ``isWellFormed`` exists to catch. Trap in
            // debug; change nothing in release.
            assertionFailure("undo: \(move.card) is not in \(move.pile.label)")
            return
        }

        history.removeLast()
        self[move.pile].remove(at: index)
        queue.insert(move.card, at: 0)
    }

    // MARK: - R4 — Custom card

    /// Adds a card the sorter wrote and puts it at the **front** of the queue
    /// (R4), so it is sorted next.
    ///
    /// Name and descriptor normalisation (trim, uppercase, default descriptor)
    /// lives in ``CustomCard``'s failable initialiser, which is also the
    /// rejection of a blank name: a nameless card is a no-op here, matching the
    /// reference's `if (!name) return`.
    ///
    /// Works with an empty queue, which is not an edge case but a requirement:
    /// SPEC R4 keeps custom cards available during Sort "including after the
    /// queue empties", so this is how the queue-empty interstitial re-enters
    /// sorting.
    ///
    /// - Returns: the card that was added, or `nil` if the name was blank.
    @discardableResult
    public mutating func addCustomCard(name: String, descriptor: String? = nil) -> CustomCard? {
        guard let card = CustomCard(name: name, descriptor: descriptor) else { return nil }

        customCards.append(card)
        queue.insert(card.cardID, at: 0)
        return card
    }
}
