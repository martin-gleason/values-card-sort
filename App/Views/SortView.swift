// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import ValuesCardSortKit

/// The sort phase (SPEC §5.2, R2–R4, R9–R11).
///
/// **The rules are not here.** `SessionState`'s verbs — `assign`, `undo`,
/// `addCustomCard` — live in `ValuesCardSortKit` and are covered by 51 tests
/// that run without a simulator. This view chooses when to call them and how
/// the result looks, and nothing else. If a rule question arises while reading
/// this file, the answer is in `SessionState+Sorting.swift`.
///
/// **Design stance (SPEC §3.1).** Everything outside the card face and its desk
/// is stock: system buttons, system fonts, system spacing. All the boldness is
/// the card. The colours come from `CardTheme`, generated from
/// `data/themes.v1.json`, every pair of which is measured by
/// `scripts/check_theme_contrast.py` — no hex literal appears in this file.
///
/// **R2 is five buttons, not a gesture** (ratified 2026-08-28). Buttons are real
/// controls, so 44pt targets, VoiceOver labels and R11's number keys fall out
/// for free; drag-to-pile would need a bespoke accessible path for every drop
/// target.
struct SortView: View {
    let deck: Deck
    let record: SessionRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var session: SessionState
    @State private var showingAddCard = false
    @State private var confirmingReset = false
    @State private var saveError: String?
    /// One announcement channel, so a screen-reader user hears what a press did
    /// rather than having to go looking for the change.
    @State private var announcement = ""

    private let theme: CardTheme = .default

    init(deck: Deck, record: SessionRecord, session: SessionState) {
        self.deck = deck
        self.record = record
        _session = State(initialValue: session)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressHeader

                if let card = currentCard {
                    CardFace(name: card.name, descriptor: card.descriptor, theme: theme)
                    pileButtons
                    secondaryActions
                    keyboardHint
                } else {
                    queueEmptyInterstitial
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.desk)
        .accessibilityIdentifier("sort-screen")
        // R11 — 1…5 assign, U undoes. `keyboardShortcut` on hidden buttons is
        // the supported route: it works with Full Keyboard Access and does not
        // steal keys from text fields, which a raw key handler would.
        .background(keyboardShortcuts)
        .sheet(isPresented: $showingAddCard) {
            AddCardSheet { name, descriptor in
                addCustomCard(name: name, descriptor: descriptor)
            }
        }
        .confirmationDialog(
            "Start over?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Erase and start over", role: .destructive) { reset() }
            Button("Keep sorting", role: .cancel) {}
        } message: {
            Text("Your entire sort will be erased. This cannot be undone.")
        }
        .alert("Could not save", isPresented: .constant(saveError != nil)) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .overlay(alignment: .bottom) {
            // A live region with no visual presence: the announcements are for
            // VoiceOver, and the screen already shows the same information.
            Text(announcement)
                .accessibilityHidden(announcement.isEmpty)
                .accessibilityAddTraits(.updatesFrequently)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase 1 of \(SessionPhase.stepCount) · Sort the deck")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onDesk)

            // The count is the accessible progress report; the bar is decoration
            // over it, so the bar is hidden from assistive technology rather
            // than announced twice.
            Text("\(session.sortedCount) of \(session.totalCards) cards sorted")
                .font(.subheadline)
                .foregroundStyle(theme.onDesk)
                .accessibilityIdentifier("sort-progress")

            ProgressView(value: Double(session.sortedCount), total: Double(max(session.totalCards, 1)))
                .tint(theme.accentOnDesk)
                .accessibilityHidden(true)
        }
    }

    // MARK: - R2

    private var pileButtons: some View {
        VStack(spacing: 8) {
            ForEach(Pile.allCases, id: \.self) { pile in
                Button {
                    assign(to: pile)
                } label: {
                    HStack(spacing: 12) {
                        Text(pile.keyboardShortcut.description)
                            .font(.footnote.monospaced())
                            .frame(minWidth: 22, minHeight: 22)
                            .overlay(Circle().strokeBorder(theme.ink, lineWidth: 1))
                        Text(pile.label)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(session.count(in: pile))")
                            .font(.footnote.monospaced())
                    }
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity)
                    .background(theme.onDesk, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pileAccessibilityLabel(for: pile))
            }
        }
    }

    /// Names the card as well as the pile, so the button says what it will
    /// actually do rather than leaving the user to remember which card is up.
    private func pileAccessibilityLabel(for pile: Pile) -> String {
        let count = session.count(in: pile)
        guard let card = currentCard else {
            return "\(pile.label). \(count) cards."
        }
        return "Sort \(card.name) into \(pile.label). \(count) already here."
    }

    // MARK: - R3, R4, R9

    /// Stacks at accessibility sizes rather than using `ViewThatFits`, which
    /// chooses a candidate by measuring it and so reports to the audit as type
    /// that will not grow. RootView switches on the same environment value.
    private var secondaryActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout { undoButton; addCardButton }
    }

    /// Stock buttons cannot be used here as-is, and that is a §3.1 tension worth
    /// naming: a bordered button's tint is chosen against a *system* background,
    /// and these sit on the themed desk, where the audit measured them failing
    /// contrast. The replacement carries no design of its own — the desk's own
    /// `onDesk` token on a lifted patch of the desk, at a system text style,
    /// with a 44pt target. Recorded in docs/departures.md.
    ///
    /// Shaped exactly like the pile buttons — colours *inside* the label, not
    /// modifiers on the Button — because that shape passes the audit and the
    /// modifier-on-Button form reported "Dynamic Type partially unsupported".
    ///
    /// No SF Symbol beside the label: RootView already learned that the icon's
    /// width is width the label needs, and the label clips at accessibility
    /// sizes.
    private func deskButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                // 0.7, not the conventional 0.4: dimmer than this the disabled
                // label falls under 4.5:1 on the lifted desk (2.58:1 at 0.4).
                // WCAG exempts inactive controls; D5 admits no exemptions, so
                // the dimming is bounded by the measurement instead.
                .foregroundStyle(theme.onDesk)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    /// Shown only once there is something to undo.
    ///
    /// A disabled control cannot be dimmed to look disabled and still clear
    /// 4.5:1 here: `.disabled` applies its own dimming on top of any opacity,
    /// and the measured floor on this surface is 0.7 (2.58:1 at the
    /// conventional 0.4). WCAG exempts inactive controls; D5 admits no
    /// exemptions. Absent is honest — before the first placement there is
    /// genuinely nothing to undo — and it removes a dead target rather than
    /// making one hard to see.
    @ViewBuilder
    private var undoButton: some View {
        if !session.history.isEmpty {
            deskButton("Undo") { undo() }
                .accessibilityIdentifier("undo")
        }
    }

    private var addCardButton: some View {
        deskButton("Write your own card") { showingAddCard = true }
            .accessibilityIdentifier("add-card")
    }

    private var keyboardHint: some View {
        // Advisory only, and hidden from VoiceOver: a screen-reader user is not
        // navigating by number key, and the pile buttons already announce theirs.
        Text("Keyboard: 1–5 to sort · U to undo")
            .font(.footnote)
            .foregroundStyle(theme.onDesk.opacity(0.85))
            .accessibilityHidden(true)
    }

    private var queueEmptyInterstitial: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardFace(
                name: "Deck sorted",
                descriptor: "All \(session.totalCards) cards placed. "
                    + "Most important: \(session.count(in: .mostImportant)).",
                theme: theme
            )
            // R4 stays available after the queue empties (SPEC R4), which is how
            // the sorter re-enters sorting from here.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { undoButton; addCardButton }
                VStack(alignment: .leading, spacing: 12) { undoButton; addCardButton }
            }
            Text("Culling arrives in F3.")
                .font(.footnote)
                .foregroundStyle(theme.onDesk)
        }
        .accessibilityIdentifier("sort-complete")
    }

    /// R11. Hidden buttons carrying only shortcuts — `.keyboardShortcut` is
    /// scoped by SwiftUI to the focused scene and ignored while a text field has
    /// focus, so typing a digit into the add-card sheet cannot sort a card.
    private var keyboardShortcuts: some View {
        ZStack {
            ForEach(Pile.allCases, id: \.self) { pile in
                Button("") { assign(to: pile) }
                    .keyboardShortcut(KeyEquivalent(pile.keyboardShortcut), modifiers: [])
            }
            Button("") { undo() }
                .keyboardShortcut("u", modifiers: [])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private var currentCard: (name: String, descriptor: String)? {
        guard let id = session.currentCard else { return nil }
        switch id {
        case .deck(let number):
            guard let card = deck[number] else { return nil }
            return (card.name, card.descriptor)
        case .custom(let uuid):
            guard let card = session.customCards.first(where: { $0.id == uuid }) else { return nil }
            return (card.name, card.descriptor)
        }
    }

    private func assign(to pile: Pile) {
        guard let card = currentCard else { return }
        session.assign(to: pile)
        announcement = "\(card.name) sorted into \(pile.label)."
        persist()
    }

    private func undo() {
        guard let move = session.history.last else { return }
        session.undo()
        let name = currentCard?.name ?? "The card"
        announcement = "\(name) taken back out of \(move.pile.label)."
        persist()
    }

    private func addCustomCard(name: String, descriptor: String) {
        guard let card = session.addCustomCard(name: name, descriptor: descriptor) else { return }
        announcement = "\(card.name) added. It is the next card."
        persist()
    }

    private func reset() {
        do {
            let store = SessionStore(context: modelContext)
            try store.abandon(record)
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// R10 — every mutation is written through, so a relaunch resumes exactly
    /// where the sorter left off rather than at the last screen boundary.
    private func persist() {
        do {
            try SessionStore(context: modelContext).save(session, to: record)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// The card face — the one place design boldness lives (SPEC §3.1).
struct CardFace: View {
    let name: String
    let descriptor: String
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.title2.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(theme.ink)
            if let ruleTop = theme.ruleTop {
                Rectangle()
                    .fill(ruleTop)
                    .frame(height: 2)
                    .accessibilityHidden(true)
            }
            Text(descriptor)
                .font(.body.italic())
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(theme.cardStock, in: RoundedRectangle(cornerRadius: 3))
        // Combined, so VoiceOver reads the card as one thing rather than as a
        // name, a decorative rule and a descriptor in three stops.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name). \(descriptor)")
        .accessibilityIdentifier("card-face")
    }
}

/// R4 — the sorter writes a card. Name required; descriptor optional and
/// defaulted. Both rules live in `CustomCard`'s failable initialiser, not here.
struct AddCardSheet: View {
    var onAdd: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var descriptor = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.characters)
                        .accessibilityIdentifier("new-card-name")
                } footer: {
                    Text("Written in capitals, to sit alongside the printed cards.")
                }
                Section {
                    TextField("What it means to you", text: $descriptor)
                        .accessibilityIdentifier("new-card-descriptor")
                } footer: {
                    Text("Optional. Left blank, it reads “\(CustomCard.defaultDescriptor)”.")
                }
            }
            .navigationTitle("Your own value")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, descriptor)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
