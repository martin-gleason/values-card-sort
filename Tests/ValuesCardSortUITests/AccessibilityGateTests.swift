// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

/// SPEC §6 — accessibility is a gate, not a feature.
///
/// docs/TESTING.md layer 4 originally described this as evidence attached to a
/// PR. Evidence is a promise; this is a check. `performAccessibilityAudit()`
/// catches the failures §6 names — unlabelled controls, targets under 44pt,
/// contrast, clipped text at large Dynamic Type sizes — and fails the build
/// when they appear, on every screen, forever.
///
/// Screenshots are still worth attaching. They are no longer the only thing
/// standing between the app and an inaccessible screen.
final class AccessibilityGateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // A fresh in-memory store per run, so the audit sees a deterministic
        // screen rather than whatever the last run left behind.
        app.launchArguments += ["--uitesting-ephemeral-store"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    func test_launchSmoke() {
        let app = launch()
        XCTAssertTrue(
            app.staticTexts["Values Card Sort"].waitForExistence(timeout: 10)
                || app.otherElements["instrument-section"].waitForExistence(timeout: 10),
            "the app did not reach its root screen"
        )
    }

    /// The deck must be readable from the *app* bundle, not just the package's
    /// test bundle — the failure mode where everything passes in CI and the
    /// shipped app shows an empty deck.
    func test_deckIsAvailableInTheShippedApp() {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["root-list"].waitForExistence(timeout: 10))

        let count = app.descendants(matching: .any)["deck-card-count"]
        // The instrument section sits below the fold on a phone.
        if !count.exists { app.descendants(matching: .any)["root-list"].swipeUp() }

        XCTAssertTrue(count.waitForExistence(timeout: 5),
                      "the instrument section should report the deck's card count")
        XCTAssertEqual(count.label, "83 value cards")
        XCTAssertFalse(app.descendants(matching: .any)["deck-unavailable"].exists,
                       "the app could not verify its own deck")
    }

    /// Contrast is scoped out **on this screen only**, and the reason is worth
    /// stating because SPEC §6 makes contrast a gate.
    ///
    /// The audit reports "Contrast nearly passed" for every text element here,
    /// including a semibold primary label on the system grouped background —
    /// a ratio around 15:1 that cannot actually be failing. What it is really
    /// reporting is low confidence: it cannot resolve an effective background
    /// behind translucent system materials and combined accessibility
    /// elements, so it flags rather than passes.
    ///
    /// Every element it named is stock SwiftUI chrome, which SPEC §3.1 makes
    /// Apple's responsibility on purpose: "the chrome is Apple's; we write
    /// none of it." Chasing these would mean hand-colouring system controls,
    /// which the design stance forbids.
    ///
    /// `.dynamicType` is scoped out for a related reason, and only after
    /// checking rather than assuming. At the default size the audit reports
    /// "Dynamic Type font sizes are partially unsupported" for four plain
    /// `Text` views that use stock text styles and therefore do scale. Running
    /// the same audit at `AccessibilityXXXL` with those views scrolled into
    /// view — `test_A11y_instrumentAttributionAtLargestDynamicTypeSize` —
    /// leaves them unflagged entirely; the only surviving issue is an element
    /// with no label and no identifier, which the app does not own. The
    /// heuristic at default size is contradicted by the real rendering at the
    /// largest size, which is the thing SPEC §6 actually requires.
    ///
    /// **`.textClipped` deliberately stays strict.** It caught a real bug in
    /// this very screen — the start button's icon left too little room and its
    /// label clipped at accessibility sizes. It is the check that earns its
    /// keep, so it is never exempted.
    ///
    /// What must NOT happen is this exemption spreading. SPEC §6's contrast
    /// requirement bites on the themed card face, where the colours are ours —
    /// so F8's themed-surface tests run the contrast audit with no exemption,
    /// alongside the computed contrast table §6 demands. Any new screen that
    /// wants this constant should first check whether it is exempting Apple's
    /// chrome or its own bug. See docs/plans/spec-deltas.md, delta 5.
    ///
    /// `.dynamicType` and `.textClipped` are iOS-only audit types; on macOS the
    /// exemption is contrast alone.
    private static var stockChromeExemptions: XCUIAccessibilityAuditType {
        #if os(macOS)
            return .contrast
        #else
            return [.contrast, .dynamicType]
        #endif
    }

    /// Exemptions for the largest-size runs: **contrast only, plus
    /// `.dynamicType` on elements the app does not own.**
    ///
    /// The blanket `.dynamicType` exemption above is justified by the claim
    /// that the flagged views come back unflagged at `AccessibilityXXXL`.
    /// Carrying a blanket exemption into these tests anyway would switch the
    /// check off at exactly the size SPEC §6 names — a future screen with a
    /// hard-coded `.font(.system(size: 17))` would sail through. An adversarial
    /// review caught that, so these runs hold the justification to its word.
    ///
    /// Running fully strict leaves exactly one issue, on an element with no
    /// label and no identifier — system scaffolding inside a stock `List`, not
    /// a view authored here. So the scope is by *ownership* rather than by
    /// rule: `.dynamicType` still fails on anything the app actually wrote.
    private static var largestSizeExemptions: XCUIAccessibilityAuditType { .contrast }

    #if os(macOS)
        private static var unownedOnly: XCUIAccessibilityAuditType { [] }
    #else
        private static var unownedOnly: XCUIAccessibilityAuditType { .dynamicType }
    #endif

    func test_A11y_launchScreenPassesAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        try assertAccessible(app, ignoring: Self.stockChromeExemptions)
    }

    /// SPEC §6: "verified at the largest accessibility size".
    func test_A11y_launchScreenAtLargestDynamicTypeSize() throws {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        try assertAccessible(app, ignoring: Self.largestSizeExemptions, onUnownedElements: Self.unownedOnly)
    }

    /// The instrument section sits below the fold, so the launch-screen audits
    /// never reach it. Attribution is a licensing obligation (SPEC §8) as well
    /// as content, so it gets its own audit at the largest size, scrolled into
    /// view where the audit can actually see it.
    func test_A11y_instrumentAttributionAtLargestDynamicTypeSize() throws {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let list = app.descendants(matching: .any)["root-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))

        let count = app.descendants(matching: .any)["deck-card-count"]
        for _ in 0..<8 where !count.isHittable {
            list.swipeUp()
        }
        XCTAssertTrue(count.exists, "could not scroll the instrument section into view")

        try assertAccessible(app, ignoring: Self.largestSizeExemptions, onUnownedElements: Self.unownedOnly)
    }

    func test_A11y_startingASortKeepsTheScreenAccessible() throws {
        let app = launch()
        let start = app.buttons["start-sort"]
        guard start.waitForExistence(timeout: 10) else {
            return XCTFail("the start control was not found")
        }
        XCTAssertFalse(start.label.isEmpty, "controls need descriptive labels (SPEC §6)")
        start.tap()

        XCTAssertTrue(app.descendants(matching: .any)["resume-sort"].waitForExistence(timeout: 5),
                      "starting a sort should show the in-progress state")
        try assertAccessible(app, ignoring: Self.stockChromeExemptions)
    }
}
