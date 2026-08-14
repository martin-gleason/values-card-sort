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
            // Resources/deck.v1.json is a symlink to ../../../data/deck.v1.json.
            // One true copy of the deck, so the file the app loads and the file
            // scripts/check-deck.sh hashes cannot diverge. The link itself is
            // asserted by that script.
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
