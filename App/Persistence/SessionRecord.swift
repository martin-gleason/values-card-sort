// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData
import ValuesCardSortKit

/// The stored form of a session (SPEC §5.1).
///
/// The rule layer's ``SessionState`` is a `Codable` value type that knows
/// nothing about SwiftData; this record is a thin envelope around it. The
/// split is deliberate:
///
/// - `ValuesCardSortKit` stays free of SwiftData, so `swift test` runs the
///   rules in milliseconds with no simulator (docs/TESTING.md "Commands").
/// - The persistence schema does not have to migrate every time a phase rule
///   gains a field — the blob absorbs it, and R10 is a `Codable` property
///   tested at both layers.
/// - Nothing here forecloses CloudKit later (SPEC §3): the queryable columns
///   are simple scalars and the model has no unsupported constructs.
///
/// The queried fields are duplicated out of the blob so the history list can
/// sort and filter without decoding every session.
@Model
final class SessionRecord {
    /// Mirrors `SessionState.id`.
    ///
    /// Deliberately **not** a `#Unique` constraint. SPEC §3 leaves the CloudKit
    /// door open — "no design decision may preclude adding CloudKit later
    /// without a rewrite" — and CloudKit-backed SwiftData containers reject
    /// unique constraints outright, so adding one here would be exactly such a
    /// decision. Everything else in this model is already CloudKit-shaped: a
    /// default on every stored property, `completedAt` optional, no
    /// unsupported constructs.
    ///
    /// Identity is enforced where it can be: `update(to:)` refuses to repoint a
    /// record at a different session, and `SessionStore.start` refuses to open
    /// a second in-progress one.
    var sessionID: UUID = UUID()

    var startedAt: Date = Date.distantPast
    /// `nil` while in progress. SPEC §5.1 allows at most one such record;
    /// ``SessionStore`` is what enforces that.
    var completedAt: Date?
    var deckVersion: String = ""

    /// The full ``SessionState``, JSON-encoded.
    var stateData: Data = Data()

    init(state: SessionState) throws {
        self.sessionID = state.id
        self.startedAt = state.startedAt
        self.completedAt = state.completedAt
        self.deckVersion = state.deckVersion
        self.stateData = try Self.encoder.encode(state)
    }

    var isInProgress: Bool { completedAt == nil }

    /// Decodes the stored session.
    ///
    /// Throws rather than returning `nil`: a session that cannot be decoded is
    /// data loss, and silently showing an empty history would hide it.
    func state() throws -> SessionState {
        try Self.decoder.decode(SessionState.self, from: stateData)
    }

    /// Writes `state` back, keeping the queryable columns in step with the
    /// blob. Every mutation must go through here — setting `stateData`
    /// directly would leave `completedAt` stale and break the
    /// at-most-one-in-progress invariant.
    func update(to state: SessionState) throws {
        precondition(state.id == sessionID, "a record must not be repointed at a different session")
        self.stateData = try Self.encoder.encode(state)
        self.completedAt = state.completedAt
        self.deckVersion = state.deckVersion
    }

    // `.deferredToDate` on purpose, rather than the more readable `.iso8601`.
    //
    // ISO-8601 has no fractional seconds in Foundation's strategy, so a
    // `Date` does not survive a round trip intact — R10 says a session resumes
    // "exactly where it left off", and a startedAt that shifts by up to a
    // second on every launch is not exact. `.deferredToDate` is a lossless
    // Double and a stable, documented format.
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
}
