// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

/// Runs `performAccessibilityAudit` and reports *which element* failed.
///
/// The bare call fails with only an audit-type name ("Contrast nearly
/// passed"), which tells you a screen is broken but not where — and a gate
/// nobody can act on gets suppressed rather than fixed. This records one
/// failure per issue, naming the element, so SPEC §6 stays enforceable as the
/// app grows.
extension XCTestCase {
    /// - Parameters:
    ///   - ignoring: audit rules switched off entirely for this screen.
    ///   - onUnownedElements: audit rules switched off **only** for elements the
    ///     app does not own — no accessibility identifier and no label, i.e.
    ///     system-supplied scaffolding inside stock containers. A rule listed
    ///     here still fails on any view the app actually authored, which is the
    ///     difference between scoping an exemption and suppressing a check.
    func assertAccessible(
        _ app: XCUIApplication,
        ignoring ignoredTypes: XCUIAccessibilityAuditType = [],
        onUnownedElements unownedTypes: XCUIAccessibilityAuditType = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        // The audit handler is not `Sendable` under Swift 6 strict
        // concurrency, so the issues are gathered through a reference the
        // closure can capture. The audit runs synchronously on this thread.
        let collector = IssueCollector()

        try app.performAccessibilityAudit(for: .all.subtracting(ignoredTypes)) { issue in
            let element = issue.element

            // An element with neither an identifier nor a label was not
            // authored here — it is scaffolding inside a stock container.
            let isUnowned = (element?.identifier ?? "").isEmpty
                && (element?.label ?? "").isEmpty
            if isUnowned, !unownedTypes.isEmpty, unownedTypes.contains(issue.auditType) {
                collector.skipped.append("\(issue.auditType.gateName) on an unowned element")
                return true
            }

            let description = """
                \(issue.auditType.gateName): \(issue.compactDescription)
                    element: \(element?.elementType.description ?? "unknown") \
                "\(element?.label ?? "")" \
                id=\(element?.identifier ?? "")
                    frame:   \(element.map { "\($0.frame)" } ?? "unknown")
                """
            collector.issues.append(description)
            // Report every issue rather than stopping at the first, so one run
            // shows the whole screen's problems.
            return true
        }

        for skip in Set(collector.skipped).sorted() {
            print("  a11y: scoped out — \(skip)")
        }

        guard collector.issues.isEmpty else {
            XCTFail(
                """
                Accessibility gate failed (SPEC §6) — \(collector.issues.count) issue(s):

                \(collector.issues.joined(separator: "\n\n"))
                """,
                file: file, line: line
            )
            return
        }
    }
}

/// Gathers audit issues across the synchronous audit callback.
private final class IssueCollector: @unchecked Sendable {
    var issues: [String] = []
    /// Recorded and printed rather than discarded — a scoped exemption that
    /// nobody ever sees is indistinguishable from a hole.
    var skipped: [String] = []
}

extension XCUIAccessibilityAuditType {
    /// A readable name, so failures cite the rule rather than a bitmask.
    var gateName: String {
        var names: [String] = []
        if contains(.contrast) { names.append("contrast") }
        if contains(.elementDetection) { names.append("element detection") }
        if contains(.hitRegion) { names.append("hit region (44pt targets)") }
        if contains(.sufficientElementDescription) { names.append("missing description") }
        #if !os(macOS)
            if contains(.dynamicType) { names.append("Dynamic Type") }
            if contains(.textClipped) { names.append("text clipped") }
        #endif
        #if !os(macOS)
            if contains(.trait) { names.append("trait") }
        #endif
        return names.isEmpty ? "unknown(\(rawValue))" : names.joined(separator: ", ")
    }
}

extension XCUIElement.ElementType {
    var description: String { "type(\(rawValue))" }
}
