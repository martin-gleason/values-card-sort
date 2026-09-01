// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI
import ValuesCardSortKit

/// Bridges a stored record to ``SortView``.
///
/// `SortView` takes a decoded `SessionState` rather than a record, so it holds
/// no opinion about persistence and stays testable. Decoding can fail — a
/// record written by a future version, or a corrupted blob — and R10 says a
/// session resumes *exactly*, so a failure to decode has to be visible rather
/// than silently restarting the sort and destroying it.
struct SortDestination: View {
    let deckResult: Result<Deck, any Error>
    let record: SessionRecord

    var body: some View {
        switch (deckResult, Result { try record.state() }) {
        case (.success(let deck), .success(let state)):
            SortView(deck: deck, record: record, session: state)
        case (.failure(let error), _):
            DeckUnavailableView(error: error)
        case (_, .failure(let error)):
            ContentUnavailableView {
                Label("This sort could not be reopened", systemImage: "exclamationmark.triangle")
            } description: {
                Text("The saved session could not be read, so it has not been changed. Starting a new sort will leave this one untouched.\n\n\(String(describing: error))")
            }
            .accessibilityIdentifier("session-unreadable")
        }
    }
}
