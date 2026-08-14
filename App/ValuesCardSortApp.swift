// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI
import ValuesCardSortKit

@main
struct ValuesCardSortApp: App {
    /// The deck is loaded and validated once, at launch. If the instrument is
    /// missing or has drifted the app says so plainly rather than starting a
    /// sort against data it cannot vouch for — fidelity is the whole claim
    /// (SPEC §2, §4).
    private let deckResult: Result<Deck, any Error> = Result { try DeckLoader.load() }

    private let storeResult: Result<ModelContainer, any Error>

    init() {
        storeResult = Result {
            // Local store only. No CloudKit in 1.0 (SPEC §3), and nothing here
            // may imply data leaves the device (SPEC §7).
            let configuration = ModelConfiguration(
                "ValuesCardSort",
                isStoredInMemoryOnly: Self.usesEphemeralStore,
                cloudKitDatabase: .none
            )
            if !Self.usesEphemeralStore { try Self.ensureStoreDirectoryExists() }
            return try ModelContainer(for: SessionRecord.self, configurations: configuration)
        }
    }

    /// UI tests run against a fresh in-memory store so the audit sees a
    /// deterministic screen.
    ///
    /// Debug-only: in a release build this is always `false`, so a shipping app
    /// cannot be launched with `--args` into a store that silently discards the
    /// sorter's work.
    private static var usesEphemeralStore: Bool {
        #if DEBUG
            return CommandLine.arguments.contains("--uitesting-ephemeral-store")
        #else
            return false
        #endif
    }

    /// SwiftData writes its store into Application Support, which does not
    /// exist in a freshly created app container — on a clean install, and on
    /// every simulator a test run provisions. Creating it is the app's job.
    private static func ensureStoreDirectoryExists() throws {
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            // A corrupt store is not a reason to crash on launch with no way
            // out. The deck failure already gets an honest screen; this one
            // gets the same treatment, so the sorter can at least read what
            // went wrong and reach the About screen.
            switch storeResult {
            case .success(let container):
                RootView(deckResult: deckResult)
                    .modelContainer(container)
            case .failure(let error):
                StoreUnavailableView(error: error)
            }
        }
        #if os(macOS)
            .defaultSize(width: 560, height: 760)
        #endif
    }
}
