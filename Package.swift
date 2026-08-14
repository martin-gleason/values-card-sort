// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

// ValuesCardSortKit is the rule layer: the deck contract, the session model,
// and the phase rules R1–R11 from SPEC §5.2.
//
// It deliberately depends on nothing but Foundation — no SwiftData, no
// SwiftUI. That keeps `swift test` fast and CI cheap (docs/TESTING.md
// "Commands"), and it means the rules can be tested without a simulator,
// a signing identity, or an app at all. The app target owns persistence and
// presentation; this package owns behavior.
let package = Package(
    name: "ValuesCardSortKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ValuesCardSortKit", targets: ["ValuesCardSortKit"]),
    ],
    targets: [
        .target(
            name: "ValuesCardSortKit",
            // Resources/deck.v1.json holds the REAL deck bytes, and
            // data/deck.v1.json — the path SPEC §4 names — is a symlink to it.
            //
            // The link points this way round for a reason worth not
            // rediscovering: SwiftPM copies resource symlinks verbatim, so a
            // link *inside* Resources/ arrives in the built bundle still
            // pointing at a relative path that no longer resolves, and the app
            // ships with no deck at all. That shipped once and was caught by a
            // failing test. scripts/check-deck.sh asserts the two paths are
            // byte-identical, by content rather than by link direction.
            resources: [.copy("Resources/deck.v1.json")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ValuesCardSortKitTests",
            dependencies: ["ValuesCardSortKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
