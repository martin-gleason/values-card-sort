// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The inset-grouped look, hand-built — and why that is not a design decision.
///
/// SPEC §3.1 says "navigation, lists, sheets, pickers, share: stock SwiftUI".
/// The intent behind that rule is that **all design boldness lives on the card
/// face and desk surface**, and nothing here departs from it: these are the
/// system's own grouped-background colours, the system's corner radius, and
/// Dynamic Type text styles throughout. Visually it is the platform's grouped
/// list. Nothing is themed and nothing is invented.
///
/// It exists because SwiftUI's `List` cannot pass a strict
/// `performAccessibilityAudit()` (SPEC §6, no exemptions — ratified
/// 2026-08-14). On the F1 root screen `List` produced six audit issues that
/// survived every remedy tried: explicit `.font` text styles, explicit
/// `foregroundStyle`, `.fixedSize(horizontal:vertical:)`, `.listStyle(.plain)`
/// and `.insetGrouped`, `.listRowBackground` with opaque colours, wrapping row
/// content in a `VStack`, collapsing rows into single accessibility elements,
/// and scrolling every row fully into view. The same content in a `ScrollView`
/// audits clean. The flags are in `List`'s backing store, not in the content.
///
/// **This is a real tension with SPEC §3.1 and is recorded as such**
/// (docs/plans/spec-deltas.md, D7). It also lands again at F6, whose session
/// history is genuinely a list with swipe-to-delete — that gate has to choose
/// between stock `List` and a passing audit, and the maintainer should make
/// that call knowing the cost.
struct GroupedSection<Content: View>: View {
    let header: String?
    @ViewBuilder var content: Content

    init(_ header: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    // Not `.secondary`: the system's grey section header sits
                    // near the contrast floor, and §6 admits no exemptions.
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.groupedContent)
            )
            .padding(.horizontal, 16)
        }
    }
}

extension Color {
    /// The platform's grouped-list background.
    static var groupedBackground: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #else
            Color(uiColor: .systemGroupedBackground)
        #endif
    }

    /// The platform's grouped-list *row* background.
    ///
    /// Opaque on purpose. The audit cannot resolve an effective contrast ratio
    /// behind a translucent material and reports "nearly passed" for text that
    /// is in fact far above the threshold; an opaque row makes the real ratio
    /// computable, and the flag goes away because the question becomes
    /// answerable rather than because it was suppressed.
    static var groupedContent: Color {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
        #else
            Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}
