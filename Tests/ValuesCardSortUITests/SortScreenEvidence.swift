// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

/// Captures the sort screen for `docs/departures.md`.
///
/// D7 requires a documented departure to carry light/dark screenshots at
/// default and largest content sizes, and `scripts/check-departures.sh`
/// enforces that every image it names exists. Producing them from a test rather
/// than by hand means the evidence is regenerable and cannot quietly describe a
/// build that no longer exists.
///
/// Extract with:
///     xcrun xcresulttool export attachments \
///       --path TestResults.xcresult --test-id <id> --output-path docs/evidence/f2
final class SortScreenEvidence: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_captureSortScreenEvidence() {
        for (appearance, style) in [("light", "light"), ("dark", "dark")] {
            for (size, category) in [
                ("default", "UICTContentSizeCategoryLarge"),
                ("ax5", "UICTContentSizeCategoryAccessibilityXXXL"),
            ] {
                let app = XCUIApplication()
                app.launchArguments += [
                    "--uitesting-ephemeral-store",
                    "-UIPreferredContentSizeCategoryName", category,
                    "-UIUserInterfaceStyle", style,
                ]
                app.launch()

                let start = app.buttons["start-sort"]
                XCTAssertTrue(start.waitForExistence(timeout: 10))
                start.tap()
                let cont = app.buttons["continue-sort"]
                XCTAssertTrue(cont.waitForExistence(timeout: 5))
                cont.tap()
                XCTAssertTrue(app.buttons["add-card"].waitForExistence(timeout: 5))

                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "sort-\(appearance)-\(size)"
                shot.lifetime = .keepAlways
                add(shot)
                app.terminate()
            }
        }
    }
}
