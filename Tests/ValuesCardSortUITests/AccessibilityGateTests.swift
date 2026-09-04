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

    // SPEC §6 admits NO exemptions (ratified 2026-08-14). Every audit rule
    // runs on every screen, at default and largest content sizes. If an audit
    // issue appears, it is fixed in the view — never waived here.
    //
    // Getting there cost the root screen its `List`: SwiftUI's List cannot
    // pass a strict audit, and no modifier fixes it. See GroupedSurface.swift
    // and docs/plans/spec-deltas.md D7.

    func test_A11y_launchScreenPassesAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        try assertAccessible(app)
    }

    /// SPEC §6: "verified at the largest accessibility size".
    func test_A11y_launchScreenAtLargestDynamicTypeSize() throws {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        try assertAccessible(app)
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

        // Scroll to the bottom, unconditionally.
        //
        // This used to read `for _ in 0..<8 where !count.isHittable`, and the
        // guard was always false: SwiftUI reports elements inside a ScrollView
        // as hittable even when they are off screen, so the loop never ran and
        // the view never moved. The audit therefore ran on the *unscrolled*
        // screen, where the intro paragraph is clipped by the bottom edge at
        // accessibility sizes — and XCUITest's contrast check on a clipped
        // element returned different verdicts on identical trees: 2 of 3
        // locally, and both outcomes on the same commit in CI.
        //
        // Scrolling until the content stops moving puts the instrument section
        // fully on screen, which is what this test exists to audit, and leaves
        // nothing clipped for the audit to disagree with itself about.
        scrollToBottom(list, probe: count)
        XCTAssertTrue(count.exists, "could not scroll the instrument section into view")

        try assertAccessible(app)
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
        try assertAccessible(app)
    }

    // MARK: - F2, the sort screen

    /// Navigates a freshly-launched app to the sort screen.
    ///
    /// Returns nil rather than failing, so a caller can report the failure at
    /// its own line and the audit tests read as audits.
    @discardableResult
    private func reachSortScreen(_ app: XCUIApplication) -> Bool {
        let start = app.buttons["start-sort"]
        guard start.waitForExistence(timeout: 10) else { return false }
        start.tap()
        let cont = app.buttons["continue-sort"]
        guard cont.waitForExistence(timeout: 5) else { return false }
        cont.tap()
        return app.otherElements["sort-screen"].waitForExistence(timeout: 5)
            || app.scrollViews["sort-screen"].waitForExistence(timeout: 5)
    }

    func test_A11y_sortScreenPassesAuditAtDefaultSize() throws {
        let app = launch()
        XCTAssertTrue(reachSortScreen(app), "could not reach the sort screen")
        try assertAccessible(app)
    }

    /// The gate that matters most for this screen: a card face plus five 44pt
    /// buttons is exactly the layout that clips at accessibility sizes, and the
    /// audit is not to be trusted on a clipped element — see F1b, where a
    /// partially-visible view produced different verdicts on identical trees.
    func test_A11y_sortScreenPassesAuditAtLargestDynamicTypeSize() throws {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(reachSortScreen(app), "could not reach the sort screen")
        try assertAccessible(app)
    }

    /// R2 — a press moves exactly one card, and the counter says so.
    func test_R2_sortingACardAdvancesTheQueue() throws {
        let app = launch()
        XCTAssertTrue(reachSortScreen(app), "could not reach the sort screen")

        let progress = app.staticTexts["sort-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.hasPrefix("0 of "), "a new sort starts at zero: \(progress.label)")

        // The pile buttons name the card they will sort, so the label is the
        // assertion that the button is wired to the right thing.
        let pile = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Most important to me")).firstMatch
        XCTAssertTrue(pile.waitForExistence(timeout: 5), "the five pile buttons should be on screen")
        XCTAssertTrue(pile.label.hasPrefix("Sort "), "a pile button should name the card: \(pile.label)")
        pile.tap()

        XCTAssertTrue(progress.label.hasPrefix("1 of "), "one card sorted: \(progress.label)")
    }

    /// R3 — undo is reachable, and returns the count.
    func test_R3_undoReturnsTheCard() throws {
        let app = launch()
        XCTAssertTrue(reachSortScreen(app), "could not reach the sort screen")

        let undo = app.buttons["undo"]
        // Absent, not disabled — a disabled control cannot be dimmed to look
        // disabled and still clear 4.5:1 on this surface. See SortView.
        XCTAssertFalse(undo.exists, "there is nothing to undo before the first placement")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sort ")).firstMatch.tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "undo appears after a placement")

        let progress = app.staticTexts["sort-progress"]
        XCTAssertTrue(progress.label.hasPrefix("1 of "))
        undo.tap()
        XCTAssertTrue(progress.label.hasPrefix("0 of "), "undo returns the card: \(progress.label)")
    }

    /// Swipes until the scroll view stops moving, i.e. it has hit the bottom.
    ///
    /// Determinism is the whole point: every run must audit the same layout.
    /// `probe`'s frame is the observable — when two consecutive swipes leave it
    /// unchanged, the content is at rest and at its end.
    private func scrollToBottom(
        _ scrollView: XCUIElement,
        probe: XCUIElement,
        maxSwipes: Int = 10
    ) {
        var previous = probe.frame
        for _ in 0..<maxSwipes {
            scrollView.swipeUp()
            let current = probe.frame
            if current == previous { return }
            previous = current
        }
    }

}
