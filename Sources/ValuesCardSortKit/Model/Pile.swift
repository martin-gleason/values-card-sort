// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The five piles a card can be sorted into (R2).
///
/// **These five labels are contract** (SPEC §5.2 R2) — they are not display
/// strings to be reworded by a designer, and they appear verbatim in the
/// markdown export (R8), so changing one silently changes exported documents
/// people have already saved.
///
/// The paper instrument has three categories; five is deliberate deviation D1
/// (SPEC §2.1) for finer first-pass triage, with ``mostImportant`` playing the
/// role the paper's "very important" pile plays in administration.
///
/// Raw values are the persisted form and must never be renumbered: they are
/// written into saved sessions. The `case` order is the display order, lowest
/// importance first, matching the reference implementation's `PILES` array and
/// the 1–5 keyboard shortcuts of R11.
public enum Pile: Int, CaseIterable, Codable, Hashable, Sendable {
    case notImportant = 0
    case somewhatImportant = 1
    case important = 2
    case veryImportant = 3
    case mostImportant = 4

    /// The contract label. Not localized in 1.0 — localization is roadmap
    /// "Later" (SPEC §9), and R8's export format depends on these exact strings.
    public var label: String {
        switch self {
        case .notImportant: "Not important to me"
        case .somewhatImportant: "Somewhat important to me"
        case .important: "Important to me"
        case .veryImportant: "Very important to me"
        case .mostImportant: "Most important to me"
        }
    }

    /// The compact form, for tight layouts and pile chips.
    public var shortLabel: String {
        switch self {
        case .notImportant: "Not important"
        case .somewhatImportant: "Somewhat important"
        case .important: "Important"
        case .veryImportant: "Very important"
        case .mostImportant: "Most important"
        }
    }

    /// The 1–5 hardware-keyboard shortcut for this pile (R11).
    public var keyboardShortcut: Character {
        Character(String(rawValue + 1))
    }

    /// Display order for the export and the sort screen, least to most
    /// important. R8 walks this reversed — the top pile prints first.
    public static var displayOrder: [Pile] { allCases }
}

/// Which step of the instrument a session is on.
public enum SessionPhase: String, Codable, CaseIterable, Sendable {
    case sort, cull, rank, export

    /// 1-based step number, for "Phase 2 of 4" chrome.
    public var stepNumber: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    public static var stepCount: Int { allCases.count }
}
