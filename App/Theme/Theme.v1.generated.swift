// SPDX-License-Identifier: GPL-3.0-or-later
//
// GENERATED FILE — DO NOT EDIT.
//
// Produced by scripts/generate_theme.py from data/themes.v1.json.
// Regenerate with: python3 scripts/generate_theme.py
//
// Every colour the card face uses comes from here, and every value here
// is measured by scripts/check_theme_contrast.py against SPEC §6's
// thresholds. A hand edit fails the regeneration check; a token change
// that drops a pair below threshold fails the contrast gate first.
//
// See D10: the reference's single ACCENT token failed four of ten pairs
// and reached two surfaces before anyone measured it.

import SwiftUI

/// A card face and the desk it sits on (SPEC §5.3).
///
/// Themes skin the card face and desk surface and nothing else — never
/// chrome, navigation or system controls (SPEC §3.1).
struct CardTheme: Sendable, Identifiable {
    let id: String
    let displayName: String
    /// True when the card renders identically in light and dark.
    ///
    /// Every pair is card-face-internal or card-on-desk: none involves a
    /// system background, so the ratios do not change with appearance. A
    /// physical card on a desk looks the same whichever way the room is lit.
    let appearanceIndependent: Bool

    let desk: Color
    let cardStock: Color
    let ink: Color
    let onDesk: Color
    /// Accent as a FILL, behind white text.
    let accentFill: Color
    /// Accent as TEXT, on the card stock. Darker than the fill: the same
    /// value cannot clear 4.5:1 in both roles.
    let accentText: Color
    /// Accent on the desk, where the surrounding luminance is far lower.
    let accentOnDesk: Color

    /// Decorative only — an index card's ruled lines identify no control
    /// and carry no information, so WCAG 1.4.11 does not scope to them.
    let rule: Color?
    let ruleTop: Color?
}

private extension Color {
    /// sRGB, matching how the contrast gate computes luminance.
    init(srgb r: Double, _ g: Double, _ b: Double) {
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

extension CardTheme {
    /// Note Card  — the default (SPEC §5.3).
    static let noteCard = CardTheme(
        id: "note-card",
        displayName: "Note Card",
        appearanceIndependent: true,
        desk: Color(srgb: 0.125490, 0.223529, 0.184314),
        cardStock: Color(srgb: 0.992157, 0.988235, 0.964706),
        ink: Color(srgb: 0.145098, 0.196078, 0.172549),
        onDesk: Color(srgb: 0.952941, 0.937255, 0.894118),
        accentFill: Color(srgb: 0.764706, 0.309804, 0.270588),
        accentText: Color(srgb: 0.627451, 0.254902, 0.223529),
        accentOnDesk: Color(srgb: 0.819608, 0.333333, 0.290196),
        rule: Color(srgb: 0.788235, 0.870588, 0.913725),
        ruleTop: Color(srgb: 0.858824, 0.603922, 0.576471)
    )

    /// Mucha.
    static let mucha = CardTheme(
        id: "mucha",
        displayName: "Mucha",
        appearanceIndependent: true,
        desk: Color(srgb: 0.145098, 0.098039, 0.160784),
        cardStock: Color(srgb: 0.941176, 0.921569, 0.894118),
        ink: Color(srgb: 0.145098, 0.105882, 0.074510),
        onDesk: Color(srgb: 0.980392, 0.972549, 0.960784),
        accentFill: Color(srgb: 0.419608, 0.309804, 0.121569),
        accentText: Color(srgb: 0.266667, 0.352941, 0.207843),
        accentOnDesk: Color(srgb: 0.803922, 0.607843, 0.262745),
        rule: nil,
        ruleTop: nil
    )

    /// Every theme this build ships, in menu order.
    static let all: [CardTheme] = [noteCard, mucha]

    /// The default until Settings ships (F9). SessionState records it per session.
    static let `default` = noteCard
}
