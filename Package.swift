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
            // No resources, deliberately.
            //
            // The deck is COMPILED IN, generated from data/deck.v1.json into
            // Deck/Deck.v1.generated.swift by scripts/generate_deck.py. The
            // shipped binary therefore carries no parsable copy of the
            // instrument text — nothing to swap on device, nothing to edit
            // quietly in a diff. See that script for the full rationale; this
            // is a hardening decision, not a packaging convenience.
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ValuesCardSortKitTests",
            dependencies: ["ValuesCardSortKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
