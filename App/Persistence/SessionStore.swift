// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData
import ValuesCardSortKit

/// Session lifecycle over a SwiftData store (SPEC §5.1).
///
/// Enforces the two rules the model type cannot enforce on its own:
/// **at most one in-progress session**, and **destroying one is deliberate**
/// (R9 — the confirmation UI belongs to F2, but the destructive call is
/// spelled `abandon` so it can never be reached by accident).
@MainActor
struct SessionStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Reading

    /// In-progress sessions, newest first.
    ///
    /// SPEC §5.1 allows at most one, and ``start(deck:customCards:themeID:)``
    /// is what keeps it that way. This returns a list rather than an optional
    /// because a restored backup — or CloudKit later, whose door SPEC §3
    /// requires stay open — can produce more than one through no fault of the
    /// app, and the store must be able to say so rather than pretend.
    func inProgressSessions() throws -> [SessionRecord] {
        try context.fetch(
            FetchDescriptor<SessionRecord>(
                predicate: #Predicate { $0.completedAt == nil },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
    }

    /// The session to resume: the newest in-progress one.
    ///
    /// **This is a read and it does not mutate.** An earlier version archived
    /// the extras here, which was wrong twice over: it wrote `completedAt` on
    /// the record while leaving the encoded blob saying `nil`, so the next
    /// ordinary read-modify-write silently un-archived it; and it permanently
    /// ended a real in-progress sort with no user interaction, which R9 says
    /// requires explicit confirmation. Resolving a duplicate is a decision for
    /// the person whose sort it is — see ``archiveDuplicateInProgressSessions``.
    func inProgress() throws -> SessionRecord? {
        try inProgressSessions().first
    }

    /// Ends every in-progress session except the newest, archiving each at its
    /// own start date.
    ///
    /// Call only after the sorter has confirmed (R9). Goes through
    /// ``SessionRecord/update(to:)`` so the blob and the queryable columns stay
    /// in step — the bug this method exists to not repeat.
    @discardableResult
    func archiveDuplicateInProgressSessions() throws -> Int {
        let records = try inProgressSessions()
        guard records.count > 1 else { return 0 }

        for stale in records.dropFirst() {
            var state = try stale.state()
            state.completedAt = stale.startedAt
            try stale.update(to: state)
        }
        try context.save()
        return records.count - 1
    }

    /// Completed sessions, newest first (SPEC §5.4).
    func completed() throws -> [SessionRecord] {
        try context.fetch(
            FetchDescriptor<SessionRecord>(
                predicate: #Predicate { $0.completedAt != nil },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
        )
    }

    func allSessions() throws -> [SessionRecord] {
        try context.fetch(
            FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        )
    }

    /// Custom cards the sorter has written in any past session (SPEC §5.1:
    /// they are offered again at the start of a new one — they are the user's
    /// personal deck extension, not session-scoped data).
    ///
    /// Throws if any stored session cannot be decoded. `SessionRecord.state()`
    /// is explicit that a session which will not decode is data loss; swallowing
    /// it here with `try?` would silently drop the sorter's own written values
    /// out of the offer and tell them nothing.
    func knownCustomCards() throws -> [CustomCard] {
        var byID: [UUID: CustomCard] = [:]
        for record in try allSessions() {
            for card in try record.state().customCards {
                byID[card.id] = card
            }
        }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Writing

    /// Starts a session (R1). Fails rather than clobbering if one is already
    /// in progress — "at most one" is an invariant, so a caller that has not
    /// resumed or abandoned first has a bug.
    @discardableResult
    func start(deck: Deck, customCards: [CustomCard] = [], themeID: String = SessionState.defaultThemeID) throws -> SessionRecord {
        guard try inProgress() == nil else { throw SessionStoreError.sessionAlreadyInProgress }

        let state = SessionState(deck: deck, customCards: customCards, themeID: themeID)
        let record = try SessionRecord(state: state)
        context.insert(record)
        try context.save()
        return record
    }

    /// Persists a mid-phase change. This is what makes R10 true: the state is
    /// written as it changes, so a launch after a crash resumes where the
    /// sorter left off rather than at the last clean exit.
    func save(_ state: SessionState, to record: SessionRecord) throws {
        try record.update(to: state)
        try context.save()
    }

    /// Marks a session finished and archives it with its date (SPEC §5.1).
    func complete(_ record: SessionRecord, at date: Date = Date()) throws {
        var state = try record.state()
        state.completedAt = date
        state.phase = .export
        try save(state, to: record)
    }

    /// Destroys a session. R9 — the caller must have confirmed first.
    func abandon(_ record: SessionRecord) throws {
        context.delete(record)
        try context.save()
    }
}

enum SessionStoreError: Error, LocalizedError {
    case sessionAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyInProgress:
            "A sort is already in progress. Resume it or start over."
        }
    }
}
