// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI
import ValuesCardSortKit

/// The app's entry screen.
///
/// **F1 scope.** This is the foundation's shell: it proves the deck loads, the
/// store opens, and a session can be started and resumed across launches
/// (R10). The sort screen itself is F2 — the placeholder below is a deliberate
/// boundary, not an unfinished feature.
///
/// Chrome is stock SwiftUI throughout, per SPEC §3.1: all design boldness is
/// reserved for the card face and desk surface, which F8 owns.
///
/// Two layout rules here exist because `performAccessibilityAudit()` caught
/// their absence (SPEC §6):
///
/// - **No side-by-side label/value rows.** `LabeledContent` puts a label and a
///   value on one line, and at the largest accessibility size the value is
///   truncated rather than wrapped. Every row stacks vertically instead.
/// - **No small secondary text.** Tertiary and secondary foreground styles at
///   footnote size sit near the contrast floor. Emphasis comes from size and
///   weight, which cost no contrast.
struct RootView: View {
    let deckResult: Result<Deck, any Error>

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var records: [SessionRecord]

    @State private var startError: String?

    private var inProgress: SessionRecord? {
        records.first { $0.isInProgress }
    }

    private var completedRecords: [SessionRecord] {
        records.filter { !$0.isInProgress }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch deckResult {
                case .success(let deck):
                    content(deck: deck)
                case .failure(let error):
                    DeckUnavailableView(error: error)
                }
            }
            .navigationTitle("Values Card Sort")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    @ViewBuilder
    private func content(deck: Deck) -> some View {
        List {
            Section("Your sort") {
                if let record = inProgress {
                    resumeRow(record: record)
                } else {
                    startRow(deck: deck)
                }
            }

            if !completedRecords.isEmpty {
                Section("Past sorts") {
                    ForEach(completedRecords) { record in
                        Text(
                            record.completedAt ?? record.startedAt,
                            format: .dateTime.year().month(.wide).day()
                        )
                        .accessibilityLabel("Completed sort")
                    }
                }
            }

            Section("Instrument") {
                Text("\(deck.cards.count) value cards")
                    .accessibilityIdentifier("deck-card-count")
                Text("Deck version \(deck.deckVersion)")

                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.instrument.title)
                        .fontWeight(.semibold)
                    Text("\(deck.instrument.authors) · \(deck.instrument.institution), \(String(deck.instrument.year)) · \(deck.instrument.copyright)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("root-list")
        .alert("Could not start", isPresented: .constant(startError != nil)) {
            Button("OK") { startError = nil }
        } message: {
            Text(startError ?? "")
        }
    }

    private func startRow(deck: Deck) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                start(deck: deck)
            } label: {
                // At accessibility sizes the icon's width is width the text
                // needs, and the label clips — caught by the Dynamic Type
                // audit, not by eye. Apple's own guidance is to drop the
                // symbol at these sizes.
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("Start a new sort")
                    } else {
                        Label("Start a new sort", systemImage: "rectangle.stack")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("start-sort")
            .accessibilityHint("Shuffles the deck and begins sorting \(deck.cards.count) cards.")

            Text("Sort \(deck.cards.count) value cards into five piles, keep your 5 to 10 most important, then rank them. Everything stays on this device.")
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private func resumeRow(record: SessionRecord) -> some View {
        let state = try? record.state()
        return VStack(alignment: .leading, spacing: 8) {
            Text("Sort in progress")
                .font(.headline)

            if let state {
                // R10's visible evidence: the exact position is restored, not
                // merely the fact that a session exists.
                Text("\(state.sortedCount) of \(state.totalCards) cards sorted")
                Text("Phase \(state.phase.stepNumber) of \(SessionPhase.stepCount)")
                    .font(.subheadline)
            }

            // F2 replaces this with the sort screen.
            Text("The sort screen arrives in F2.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("resume-sort")
    }

    private func start(deck: Deck) {
        do {
            let store = SessionStore(context: modelContext)
            try store.start(deck: deck, customCards: try store.knownCustomCards())
        } catch {
            startError = error.localizedDescription
        }
    }
}

/// Shown when the bundled instrument is missing or has drifted (SPEC §4).
///
/// A dedicated screen rather than an alert: without a faithful deck this app
/// has nothing to offer, and saying so plainly is better than degrading.
struct DeckUnavailableView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("The deck could not be loaded", systemImage: "exclamationmark.triangle")
        } description: {
            Text("This app will not run a sort against a deck it cannot verify against the printed instrument.\n\n\(String(describing: error))")
        }
        .accessibilityIdentifier("deck-unavailable")
    }
}

/// Shown when the local session store will not open.
///
/// The alternative was `fatalError`, i.e. crash-on-launch with no path out for
/// someone whose store got corrupted. Flagged in adversarial review as
/// inconsistent with the care taken over `DeckUnavailableView` a few lines away.
struct StoreUnavailableView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Your saved sorts could not be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("The app could not open its local storage, so it cannot show or save sorts right now. Nothing has been sent anywhere — this app makes no network connections.\n\n\(String(describing: error))")
        }
        .accessibilityIdentifier("store-unavailable")
    }
}

#Preview("Deck loaded") {
    RootView(deckResult: Result { try DeckLoader.load() })
        .modelContainer(for: SessionRecord.self, inMemory: true)
}

#Preview("Deck missing") {
    RootView(deckResult: .failure(DeckError.countMismatch(declared: 83, actual: 0)))
        .modelContainer(for: SessionRecord.self, inMemory: true)
}
