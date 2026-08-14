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

    private let container: ModelContainer

    init() {
        do {
            // Local store only. No CloudKit in 1.0 (SPEC §3), and nothing here
            // may imply data leaves the device (SPEC §7).
            let ephemeral = CommandLine.arguments.contains("--uitesting-ephemeral-store")
            let configuration = ModelConfiguration(
                "ValuesCardSort",
                isStoredInMemoryOnly: ephemeral,
                cloudKitDatabase: .none
            )
            if !ephemeral { try Self.ensureStoreDirectoryExists() }
            container = try ModelContainer(for: SessionRecord.self, configurations: configuration)
        } catch {
            fatalError("Could not open the local session store: \(error)")
        }
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
            RootView(deckResult: deckResult)
        }
        .modelContainer(container)
        #if os(macOS)
            .defaultSize(width: 560, height: 760)
        #endif
    }
}
