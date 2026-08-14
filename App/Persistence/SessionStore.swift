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

    /// The single in-progress session, if there is one.
    ///
    /// If a bad merge or restored backup ever produced more than one, the
    /// newest wins and the rest are archived rather than deleted — losing a
    /// user's sort silently would be the worst possible failure here.
    func inProgress() throws -> SessionRecord? {
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        guard let newest = records.first else { return nil }

        for stale in records.dropFirst() {
            stale.completedAt = stale.startedAt
        }
        if records.count > 1 { try context.save() }

        return newest
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
    func knownCustomCards() throws -> [CustomCard] {
        var byID: [UUID: CustomCard] = [:]
        for record in try allSessions() {
            for card in (try? record.state())?.customCards ?? [] {
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
